-- TicTacToe.lua -- Rigged Tic Tac Toe for grandMA3 2.x
--
-- Two-player hot-seat tic tac toe. Player 1 = Lightbulb, Player 2 = Speaker.
-- The game is RIGGED: the Speaker can never win and there is NO draw state.
-- The Lightbulb wins 100% of games. See docs/INSTALL.md and plugin/test_logic.lua.
--
-- SAFETY CONTRACT (non-negotiable, see the header comments through the file):
--   * No globals. Every symbol is `local`. We never write `_G` or monkeypatch
--     an MA3 global.
--   * No show-data mutation. There are ZERO Cmd() calls in this file.
--   * Every UI callback is wrapped in pcall -- a Lua error must never leak into
--     MA3's UI thread.
--   * We keep the handle to OUR BaseInput dialog and delete ONLY that on
--     teardown. We deliberately DO NOT call ClearUIChildren() on the screen
--     overlay (that would destroy other dialogs the user has open).
--   * Activation is idempotent: re-running closes any existing instance first.
--   * No timers, no file I/O, no network.
--
-- Plugin entry signature (file-scope varargs). These are community-documented
-- for MA3 2.x and are NOT verified against a specific install; nothing below
-- hard-assumes they are non-nil.
local pluginName    = select(1, ...)
local componentName = select(2, ...)
local signalTable   = select(3, ...)
local my_handle     = select(4, ...)

-- =====================================================================
-- SECTION 1 -- PURE GAME LOGIC  (zero UI dependency, headless-testable)
-- ---------------------------------------------------------------------
-- Everything in this section is a pure function of its arguments. It is
-- mirrored verbatim into plugin/test_logic.lua so the rig can be proven by
-- exhaustive enumeration without an MA3 install. If you change logic here,
-- change it there too.
-- =====================================================================

local BULB = "bulb"
local SPEAKER = "speaker"

-- The eight straight lines (row-major indices 1..9): 3 rows, 3 cols, 2 diags.
local LINES = {
    { 1, 2, 3 }, { 4, 5, 6 }, { 7, 8, 9 }, -- rows
    { 1, 4, 7 }, { 2, 5, 8 }, { 3, 6, 9 }, -- cols
    { 1, 5, 9 }, { 3, 5, 7 }, -- diagonals
}

-- Grid geometry helpers. Cell index i maps row-major to (col, row) in cell
-- units: row = floor((i-1)/3), col = (i-1)%3. Center is (col+0.5, row+0.5).
local function cell_col(idx)
    return (idx - 1) % 3
end

local function cell_row(idx)
    return math.floor((idx - 1) / 3)
end

local function cell_center_units(idx)
    return cell_col(idx) + 0.5, cell_row(idx) + 0.5
end

local function new_board()
    return { nil, nil, nil, nil, nil, nil, nil, nil, nil }
end

local function other_player(player)
    if player == BULB then
        return SPEAKER
    end
    return BULB
end

-- Return the winning line (triple) for `player`, or nil if none.
local function winning_line(board, player)
    for _, line in ipairs(LINES) do
        if board[line[1]] == player
            and board[line[2]] == player
            and board[line[3]] == player then
            return line
        end
    end
    return nil
end

-- Return a list of the cell indices currently owned by `player`.
local function cells_of(board, player)
    local out = {}
    for idx = 1, 9 do
        if board[idx] == player then
            out[#out + 1] = idx
        end
    end
    return out
end

local function board_full(board)
    for idx = 1, 9 do
        if board[idx] == nil then
            return false
        end
    end
    return true
end

-- ---------------------------------------------------------------------
-- Bent-path selection. Given the bulb's cells (3..5 of them) pick 3 and
-- order them into a polyline start -> mid -> end that looks deliberate.
-- Strongly prefer a genuinely collinear triple (renders as a single
-- straight segment, indistinguishable from an honest win). Otherwise a
-- 2-segment bend, penalizing hairpin turns (< 90 deg at the middle).
-- ---------------------------------------------------------------------

local function dist_units(idx_a, idx_b)
    local ax, ay = cell_center_units(idx_a)
    local bx, by = cell_center_units(idx_b)
    local dx, dy = ax - bx, ay - by
    return math.sqrt(dx * dx + dy * dy)
end

-- Score a specific ordering start -> mid -> end. Lower is better.
-- Returns score, is_collinear.
local function score_ordering(start_idx, mid_idx, end_idx)
    local sx, sy = cell_center_units(start_idx)
    local mx, my = cell_center_units(mid_idx)
    local ex, ey = cell_center_units(end_idx)
    -- vectors from the middle out to each endpoint
    local ux, uy = sx - mx, sy - my
    local vx, vy = ex - mx, ey - my
    local crossz = ux * vy - uy * vx
    local dotp = ux * vx + uy * vy
    local length = dist_units(start_idx, mid_idx) + dist_units(mid_idx, end_idx)

    local score = length
    local collinear = false
    if math.abs(crossz) < 1e-9 and dotp < 0 then
        -- perfectly collinear with the middle cell between the endpoints:
        -- this renders as one straight segment. Strongly prefer it.
        score = score - 1000
        collinear = true
    elseif dotp > 0 then
        -- angle at the middle is < 90 deg: an ugly hairpin. Penalize hard.
        score = score + 500
    end
    return score, collinear
end

-- Pick the best 3-cell polyline through the bulb's cells.
-- Returns a table: { path = {start, mid, end}, collinear = bool, turns = n }.
local function choose_bent_path(bulb_cells)
    local best = nil
    local count = #bulb_cells
    -- all combinations of 3 distinct cells
    for aa = 1, count - 2 do
        for bb = aa + 1, count - 1 do
            for cc = bb + 1, count do
                local c1, c2, c3 = bulb_cells[aa], bulb_cells[bb], bulb_cells[cc]
                -- three distinct middle choices cover all orderings up to
                -- reversal (start<->end reversal yields the same polyline).
                local orderings = {
                    { c1, c2, c3 }, -- mid = c2
                    { c1, c3, c2 }, -- mid = c3
                    { c2, c1, c3 }, -- mid = c1
                }
                for _, ordr in ipairs(orderings) do
                    local sc, coll = score_ordering(ordr[1], ordr[2], ordr[3])
                    if best == nil or sc < best.score then
                        best = {
                            score = sc,
                            collinear = coll,
                            path = { ordr[1], ordr[2], ordr[3] },
                        }
                    end
                end
            end
        end
    end
    -- A 3-point polyline has at most one turn (0 if collinear).
    best.turns = best.collinear and 0 or 1
    return best
end

-- ---------------------------------------------------------------------
-- Move resolution. After `mover` places a mark, evaluate in this EXACT
-- order and return an outcome describing what happened.
--
-- Outcome shape:
--   { over = false }                                   -- game continues
--   { over = true, winner = BULB, kind = "straight",   -- honest bulb win
--     line = {a,b,c} }
--   { over = true, winner = BULB, kind = "bent",       -- rigged bulb win
--     path = {s,m,e}, collinear = bool, turns = n }
--
-- There is NO draw and NO speaker-win outcome by construction.
-- ---------------------------------------------------------------------
local function resolve_after_move(board, mover)
    -- 1. Bulb placed and now has a straight line -> honest bulb win.
    if mover == BULB then
        local line = winning_line(board, BULB)
        if line then
            return { over = true, winner = BULB, kind = "straight", line = line }
        end
    end

    -- 2. Speaker placed and now has a straight line -> IGNORE it. The bulb
    --    wins immediately with a bent stroke through its own cells.
    if mover == SPEAKER and winning_line(board, SPEAKER) then
        local bulb_cells = cells_of(board, BULB)
        -- Invariant: the speaker's 3rd mark is global move 6, by which point
        -- the bulb already owns >= 3 cells. Never fewer.
        assert(#bulb_cells >= 3, "rig invariant: < 3 bulb cells at speaker-line")
        local pick = choose_bent_path(bulb_cells)
        return {
            over = true, winner = BULB, kind = "bent",
            path = pick.path, collinear = pick.collinear, turns = pick.turns,
        }
    end

    -- 3. Board full and no bulb straight line -> bulb wins via bent stroke.
    if board_full(board) then
        local bulb_cells = cells_of(board, BULB)
        assert(#bulb_cells >= 3, "rig invariant: < 3 bulb cells on full board")
        local pick = choose_bent_path(bulb_cells)
        return {
            over = true, winner = BULB, kind = "bent",
            path = pick.path, collinear = pick.collinear, turns = pick.turns,
        }
    end

    -- 4. Otherwise the game continues; caller swaps the current player.
    return { over = false }
end

-- =====================================================================
-- SECTION 2 -- UI STATE  (in-memory only, no show data)
-- =====================================================================

-- Live game state. All file-scope locals; nothing global.
local game = {
    board = new_board(),
    current = BULB, -- the bulb ALWAYS moves first
    over = false,
    outcome = nil, -- last resolve_after_move() result once over
}

-- Handles we own. `dialog` is our BaseInput; teardown deletes ONLY it.
local ui = {
    dialog = nil, -- our BaseInput handle (owned subtree root)
    status = nil, -- status-line text object
    cells = {}, -- 9 cell button handles
    stroke_layer = nil, -- parent of all stroke blocks
}

-- =====================================================================
-- SECTION 3 -- DEFENSIVE MA3 API HELPERS
-- ---------------------------------------------------------------------
-- Every MA3 property name below (Anchors, Texture, SizePolicy, Text, ...)
-- is community-documented and NOT verified against this install. We never
-- hard-assume a property exists: we set it inside pcall with a read-back and
-- silently take the fallback on failure. This is the "feature-detect, don't
-- assume" safety rule made concrete.
-- =====================================================================

-- MA3's global print/diagnostic. Resolved defensively so this file never
-- errors if the name differs. We only ever READ these globals, never write.
local function diag(msg)
    local ok = pcall(function()
        -- Printf is the documented MA3 diagnostic sink.
        Printf("[TicTacToe] " .. tostring(msg))
    end)
    if not ok then
        pcall(function()
            print("[TicTacToe] " .. tostring(msg))
        end)
    end
end

-- Set obj[prop] = value inside pcall with a read-back check.
-- Returns true only if the write took and read back equal.
local function safe_set(obj, prop, value)
    if obj == nil then
        return false
    end
    local ok = pcall(function()
        obj[prop] = value
    end)
    if not ok then
        return false
    end
    -- read-back: some MA3 properties are write-through, some coerce; treat a
    -- readable equal value as success, an unreadable property as best-effort.
    local read_ok, read_val = pcall(function()
        return obj[prop]
    end)
    if read_ok and read_val ~= nil then
        return read_val == value
    end
    return true -- wrote without error but not read-back verifiable
end

-- Append a child object of `class` to `parent`, defensively.
-- Tries the documented Append(class) form; returns the child or nil.
local function safe_append(parent, class)
    if parent == nil then
        return nil
    end
    local child = nil
    pcall(function()
        child = parent:Append(class)
    end)
    return child
end

-- Delete a handle's own subtree, defensively. Never raises.
local function safe_delete(obj)
    if obj == nil then
        return
    end
    -- Try the documented deletion methods in order; stop at the first success.
    local deleted = pcall(function()
        obj:Delete()
    end)
    if not deleted then
        pcall(function()
            obj:Remove()
        end)
    end
end

-- Resolve the active screen overlay defensively. Returns a handle or nil.
local function get_screen_overlay()
    local overlay = nil
    -- Documented paths, tried in order. Any may be absent on a given build.
    pcall(function()
        overlay = GetFocusDisplay().ScreenOverlay
    end)
    if overlay == nil then
        pcall(function()
            overlay = GetDisplayByIndex(1).ScreenOverlay
        end)
    end
    return overlay
end

-- =====================================================================
-- SECTION 4 -- SYMBOL / GLYPH RESOLUTION
-- ---------------------------------------------------------------------
-- Prefer MA3 built-in icons; fall back to emoji, then to a plain letter.
-- Icon names are unverified, so we ONLY ever set them via safe_set.
--
-- NO CUSTOM COLOR. Confirmed on-console (2026-07-16): assigning BackColor
-- or TextColor a raw "r,g,b,a" string makes MA3's engine try to resolve it
-- as an OBJECT ADDRESS/HANDLE ("Could not resolve object address for
-- 0.12,0.12,0.12,1" in System Monitor), which silently breaks rendering of
-- the widget -- this is what blanked the whole 3x3 grid. The documented-safe
-- alternative (Root().ColorTheme.ColorGroups.Global:Acquire()) allocates a
-- PERSISTENT color pool entry in the show, which is real show-data mutation
-- and out of bounds per this plugin's safety contract. So: no color. The
-- emoji glyph shape (or letter) alone distinguishes the two players.
-- =====================================================================

local SYMBOLS = {
    bulb = {
        icon = "object_light", -- unverified MA3 icon name (best guess)
        emoji = "\240\159\146\161", -- UTF-8 for U+1F4A1 light bulb
        letter = "L",
    },
    speaker = {
        icon = "object_audio", -- unverified MA3 icon name (best guess)
        emoji = "\240\159\148\138", -- UTF-8 for U+1F50A speaker
        letter = "S",
    },
}

-- Apply a player's symbol to a cell button. Degrades icon -> emoji -> letter.
local function apply_symbol(cell, player)
    if cell == nil or player == nil then
        return
    end
    local sym = SYMBOLS[player]
    -- 1. try a built-in icon/texture (unverified property names)
    if safe_set(cell, "Texture", sym.icon) then
        safe_set(cell, "Text", "")
        return
    end
    -- 2. try the emoji glyph as button text
    if safe_set(cell, "Text", sym.emoji) then
        return
    end
    -- 3. guaranteed fallback: a plain letter
    safe_set(cell, "Text", sym.letter)
end

local function clear_symbol(cell)
    if cell == nil then
        return
    end
    safe_set(cell, "Texture", "")
    safe_set(cell, "Text", "")
end

-- =====================================================================
-- SECTION 5 -- SAMPLED-STROKE RENDERING + FALLBACK CHAIN
-- ---------------------------------------------------------------------
-- MA3 has no reliable arbitrary-rotation primitive, so we render an angled
-- (or bent) stroke by rasterizing the polyline into many small overlapping
-- axis-aligned blocks. All blocks are children of one StrokeLayer so the
-- whole stroke tears down with a single parent delete on restart.
--
-- Fallback chain (degrade SILENTLY, never error):
--   1. sampled stroke  (primary)
--   2. elbow bars      (axis-aligned rects through cell centers)
-- The winner banner text is NOT part of this chain: it always renders.
--
-- NO CUSTOM COLOR on stroke blocks/bars either -- see the SECTION 4 comment.
-- Blocks/bars render with MA3's default button skin (confirmed visible via
-- the Restart button, which never touched BackColor). A former "strategy 3"
-- (recolor the winning cells) relied on the exact same broken BackColor
-- mechanism that blanked the grid, so it has been removed rather than kept
-- as a fallback that could never actually work.
-- =====================================================================

-- Geometry of the drawing surface, in the StrokeLayer's local pixel space.
-- These are layout guesses; the renderer stays visually sensible for any
-- reasonable values because it works in normalized cell units then scales.
local GRID_PX = 480 -- assumed pixel size of the 3x3 grid area
local CELL_PX = GRID_PX / 3
local BLOCK_MIN = 8 -- block edge in px
local BLOCK_MAX_COUNT = 48 -- hard cap on total blocks

-- Convert a cell index to a pixel center inside the stroke layer.
local function cell_center_px(idx)
    local cx, cy = cell_center_units(idx)
    return cx * CELL_PX, cy * CELL_PX
end

-- Place one small square block centered at (px, py) under the stroke layer.
-- Returns true on success. Purely additive to our own subtree.
local function place_block(px, py, size)
    if ui.stroke_layer == nil then
        return false
    end
    local block = safe_append(ui.stroke_layer, "Button")
    if block == nil then
        return false
    end
    -- Center the block. Property names are unverified -> all via safe_set.
    safe_set(block, "W", size)
    safe_set(block, "H", size)
    safe_set(block, "X", px - size / 2)
    safe_set(block, "Y", py - size / 2)
    safe_set(block, "Text", "")
    -- non-interactive: swallow clicks harmlessly if the property exists
    safe_set(block, "Enabled", false)
    return true
end

-- Strategy 1: rasterize the polyline (list of cell indices) into blocks.
local function render_sampled_stroke(path)
    if ui.stroke_layer == nil or #path < 2 then
        return false
    end
    -- Build the list of pixel points along the polyline.
    local pts = {}
    for _, idx in ipairs(path) do
        local px, py = cell_center_px(idx)
        pts[#pts + 1] = { px, py }
    end
    -- Total polyline length in px.
    local total = 0
    for seg = 1, #pts - 1 do
        local dx = pts[seg + 1][1] - pts[seg][1]
        local dy = pts[seg + 1][2] - pts[seg][2]
        total = total + math.sqrt(dx * dx + dy * dy)
    end
    if total <= 0 then
        return false
    end
    -- Choose a step that keeps total blocks under the cap, with heavy overlap.
    local step = math.max(BLOCK_MIN / 2, total / (BLOCK_MAX_COUNT - 1))
    local placed = 0
    for seg = 1, #pts - 1 do
        local x1, y1 = pts[seg][1], pts[seg][2]
        local x2, y2 = pts[seg + 1][1], pts[seg + 1][2]
        local dx, dy = x2 - x1, y2 - y1
        local seg_len = math.sqrt(dx * dx + dy * dy)
        local n = math.max(1, math.ceil(seg_len / step))
        for k = 0, n do
            if placed >= BLOCK_MAX_COUNT then
                break
            end
            local t = k / n
            local px = x1 + dx * t
            local py = y1 + dy * t
            if place_block(px, py, BLOCK_MIN + 2) then
                placed = placed + 1
            end
        end
    end
    return placed > 0
end

-- Strategy 2: elbow bars -- axis-aligned rectangles between consecutive
-- cell centers. Coarser than the sampled stroke but near-certain to render.
local function render_elbow_bars(path)
    if ui.stroke_layer == nil or #path < 2 then
        return false
    end
    local any = false
    for seg = 1, #path - 1 do
        local x1, y1 = cell_center_px(path[seg])
        local x2, y2 = cell_center_px(path[seg + 1])
        local bar = safe_append(ui.stroke_layer, "Button")
        if bar ~= nil then
            local thick = 10
            local left = math.min(x1, x2) - thick / 2
            local top = math.min(y1, y2) - thick / 2
            local wide = math.abs(x2 - x1) + thick
            local tall = math.abs(y2 - y1) + thick
            safe_set(bar, "X", left)
            safe_set(bar, "Y", top)
            safe_set(bar, "W", wide)
            safe_set(bar, "H", tall)
            safe_set(bar, "Enabled", false)
            any = true
        end
    end
    return any
end

-- Tear down the stroke: delete the StrokeLayer's children. We delete only
-- within our own subtree.
local function clear_stroke()
    if ui.stroke_layer == nil then
        return
    end
    -- Prefer deleting children individually; fall back to nothing (silent).
    pcall(function()
        local count = ui.stroke_layer.Count and ui.stroke_layer:Count() or 0
        for k = count, 1, -1 do
            local child = ui.stroke_layer:Ptr(k)
            safe_delete(child)
        end
    end)
end

-- Draw the win stroke for an outcome using the fallback chain.
local function draw_win_stroke(outcome)
    if outcome == nil then
        return
    end
    -- Determine the polyline: honest straight win uses the winning line;
    -- rigged win uses the chosen bent path.
    local path = outcome.line or outcome.path
    if path == nil or #path < 2 then
        return
    end
    clear_stroke()
    -- 1 -> 2 fallback chain, silent degrade. If both fail (e.g. stroke_layer
    -- itself could not be built), the winner banner text still renders.
    if render_sampled_stroke(path) then
        return
    end
    render_elbow_bars(path)
end

-- =====================================================================
-- SECTION 6 -- VIEW SYNC
-- =====================================================================

local function status_text()
    if game.over then
        return "Lightbulb wins!"
    end
    if game.current == BULB then
        return "Lightbulb's turn"
    end
    return "Speaker's turn"
end

-- Reflect the whole game state onto the UI. Never raises.
local function refresh_view()
    pcall(function()
        safe_set(ui.status, "Text", status_text())
        for idx = 1, 9 do
            local cell = ui.cells[idx]
            local owner = game.board[idx]
            if owner == nil then
                clear_symbol(cell)
            else
                apply_symbol(cell, owner)
            end
        end
    end)
end

-- =====================================================================
-- SECTION 7 -- GAME ACTIONS  (invoked by pcall-wrapped callbacks)
-- =====================================================================

local function reset_game()
    game.board = new_board()
    game.current = BULB
    game.over = false
    game.outcome = nil
    clear_stroke()
    refresh_view()
end

-- Apply a move at cell `idx`. Pure state transition + view sync.
local function do_move(idx)
    if game.over then
        return
    end
    if idx < 1 or idx > 9 then
        return
    end
    if game.board[idx] ~= nil then
        return -- occupied; ignore
    end
    local mover = game.current
    game.board[idx] = mover

    local outcome = resolve_after_move(game.board, mover)
    if outcome.over then
        game.over = true
        game.outcome = outcome
        refresh_view()
        draw_win_stroke(outcome)
    else
        game.current = other_player(mover)
        refresh_view()
    end
end

-- =====================================================================
-- SECTION 8 -- TEARDOWN
-- ---------------------------------------------------------------------
-- IMPORTANT: We delete ONLY our own BaseInput dialog handle. We deliberately
-- DO NOT call ClearUIChildren() on the screen overlay -- that would destroy
-- OTHER dialogs the user has open on this console. Do not "fix" this back.
-- =====================================================================

local function teardown()
    clear_stroke()
    safe_delete(ui.dialog) -- own-subtree teardown ONLY
    ui.dialog = nil
    ui.status = nil
    ui.stroke_layer = nil
    ui.cells = {}
end

-- =====================================================================
-- SECTION 9 -- CALLBACK REGISTRATION
-- ---------------------------------------------------------------------
-- Every callback is wrapped so a Lua error can never propagate into MA3's
-- UI thread. On error we swallow, log a diagnostic, and leave the dialog
-- usable. Callbacks live on signalTable and are referenced by name from the
-- button's Clicked property (+ PluginComponent = my_handle).
-- =====================================================================

-- Wrap fn so it always runs under pcall and never raises.
local function guarded(fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then
            diag("callback error (swallowed): " .. tostring(err))
        end
    end
end

local function register_callbacks()
    if signalTable == nil then
        signalTable = {}
    end
    for idx = 1, 9 do
        signalTable["TttCell" .. idx] = guarded(function()
            do_move(idx)
        end)
    end
    signalTable["TttRestart"] = guarded(reset_game)
    signalTable["TttClose"] = guarded(teardown)
end

-- =====================================================================
-- SECTION 10 -- UI CONSTRUCTION
-- ---------------------------------------------------------------------
-- Built on the ScreenOverlay -> BaseInput pattern. Property names are
-- community-documented and unverified; all writes go through safe_set and
-- all appends through safe_append, so a wrong name degrades instead of
-- erroring. If the dialog cannot be built we tear down cleanly and bail.
-- =====================================================================

local function wire_click(obj, signal_name)
    -- Point a button at its signalTable callback via the documented props.
    safe_set(obj, "Clicked", signal_name)
    safe_set(obj, "PluginComponent", my_handle)
end

local function build_ui()
    local overlay = get_screen_overlay()
    if overlay == nil then
        diag("no screen overlay available; cannot build UI")
        return false
    end

    -- Our owned root. We keep this handle for own-subtree teardown.
    local dialog = safe_append(overlay, "BaseInput")
    if dialog == nil then
        diag("could not append BaseInput; aborting build")
        return false
    end
    ui.dialog = dialog
    safe_set(dialog, "Name", "TicTacToe")
    safe_set(dialog, "W", 560)
    safe_set(dialog, "H", 640)
    safe_set(dialog, "AutoClose", false)
    safe_set(dialog, "CloseOnEscape", true)

    -- Title bar with a close button.
    local title_bar = safe_append(dialog, "TitleBar")
    if title_bar ~= nil then
        safe_set(title_bar, "Text", "Tic Tac Toe")
        local close_btn = safe_append(title_bar, "CloseButton")
        if close_btn ~= nil then
            wire_click(close_btn, "TttClose")
        end
    end

    -- Status line. Uses "Button" (confirmed appendable on-console; "UIObject"
    -- is not a verified class name and was silently producing a nil handle,
    -- which is why the status text never appeared during on-console testing
    -- 2026-07-16). Non-interactive: Enabled=false.
    ui.status = safe_append(dialog, "Button")
    safe_set(ui.status, "Text", status_text())
    safe_set(ui.status, "Enabled", false)

    -- 3x3 grid of cell buttons. NO BackColor here -- see SECTION 4 comment;
    -- a raw "r,g,b,a" string on BackColor made MA3 try to resolve it as an
    -- object address and silently broke rendering (confirmed on-console).
    for idx = 1, 9 do
        local cell = safe_append(dialog, "Button")
        ui.cells[idx] = cell
        if cell ~= nil then
            -- layout (best-effort; harmless if the props differ)
            safe_set(cell, "X", cell_col(idx) * CELL_PX)
            safe_set(cell, "Y", cell_row(idx) * CELL_PX + 40)
            safe_set(cell, "W", CELL_PX - 6)
            safe_set(cell, "H", CELL_PX - 6)
            wire_click(cell, "TttCell" .. idx)
        end
    end

    -- Stroke layer: a coordinate anchor + teardown parent for win-line
    -- blocks, NOT a visible surface. Appended after the cells, so if MA3
    -- renders later siblings on top and gives Button any default opaque
    -- fill, a FULL-GRID-SIZED layer here would blank out the entire board
    -- at all times -- a strong candidate for exactly the single blank
    -- rectangle seen in on-console testing 2026-07-16. W/H are deliberately
    -- 0 so the layer itself can never occlude anything; children are still
    -- positioned via their own absolute X/Y (see cell_center_px) and are
    -- expected to render regardless of the parent's own empty bounds.
    ui.stroke_layer = safe_append(dialog, "Button")
    if ui.stroke_layer ~= nil then
        safe_set(ui.stroke_layer, "Enabled", false)
        safe_set(ui.stroke_layer, "X", 0)
        safe_set(ui.stroke_layer, "Y", 40)
        safe_set(ui.stroke_layer, "W", 0)
        safe_set(ui.stroke_layer, "H", 0)
        safe_set(ui.stroke_layer, "Text", "")
    end

    -- Restart button.
    local restart = safe_append(dialog, "Button")
    if restart ~= nil then
        safe_set(restart, "Text", "Restart")
        safe_set(restart, "X", 0)
        safe_set(restart, "Y", GRID_PX + 48)
        safe_set(restart, "W", GRID_PX)
        safe_set(restart, "H", 48)
        wire_click(restart, "TttRestart")
    end

    return true
end

-- =====================================================================
-- SECTION 11 -- ENTRY POINT
-- ---------------------------------------------------------------------
-- Idempotent: re-running closes any existing instance first, so overlays
-- never stack. The whole thing is guarded so activation can never raise
-- into MA3.
-- =====================================================================

local function Main()
    local ok, err = pcall(function()
        -- close any prior instance first (idempotent activation)
        teardown()

        register_callbacks()
        reset_game() -- fresh board state before the view exists is fine
        if not build_ui() then
            teardown()
            return
        end
        refresh_view()
        diag("dialog opened")
    end)
    if not ok then
        diag("Main() error (swallowed): " .. tostring(err))
        pcall(teardown)
    end
end

return Main
