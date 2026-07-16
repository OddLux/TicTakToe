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
    overlay = nil, -- the screen overlay `dialog` is a child of (for deletion)
    dialog = nil, -- our BaseInput handle (owned subtree root)
    status = nil, -- status-line text object
    cells = {}, -- 9 cell button handles
    stroke_blocks = {}, -- win-line block handles (direct children of dialog)
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

-- ---------------------------------------------------------------------
-- UI child deletion.
--
-- Ground truth (2026-07-16): the console's OWN `HelpLua`-generated function
-- dump (C:/ProgramData/MALightingTechnology/gma3_library/
-- grandMA3_lua_functions.txt on the user's machine -- authoritative for
-- this exact build, not a third-party mirror) lists:
--   `Delete(light_userdata:handle, integer:child_index(1-based)[, undo]):
--   nothing`
-- i.e. a PARENT-indexed global: you delete a child FROM its parent by
-- index, not the child object itself. The previous `child:Delete()` (no
-- args) is why every stroke block failed to delete and spammed System
-- Monitor with "returns nothing" for each one.
--
-- After switching to a parent+index call, deletion STILL silently failed
-- with no errors visible in System Monitor. Two candidate explanations,
-- both plausible and NOT yet distinguished by evidence:
--   (a) `Delete` isn't actually a bare global despite the doc listing it
--       without a "Handle:" prefix -- calling a nil global raises "attempt
--       to call a nil value", which our own pcall swallows silently. This
--       would look identical to "nothing happened."
--   (b) `Delete` IS callable (via colon sugar, like `Append`/`Count`/`Ptr`
--       all proven to be) but resolving "which index is this child" by
--       comparing handles for equality (`GetUIChild(parent, i) == child`)
--       doesn't reliably match, so the delete call is simply never reached.
-- Rather than guess a third convention blindly, try_delete below attempts
-- BOTH the colon-method and bare-global forms, verifies success via an
-- actual count decrease (not just "no error"), and -- critically -- logs
-- via diag() whenever a pcall catches something, so the NEXT System
-- Monitor screenshot gives a definitive answer instead of another silent
-- "still doesn't work."
--
-- Two different deletion strategies follow, chosen per call site:
--   * delete_last_ui_child: no equality check at all -- always targets
--     the CURRENT last child by count. Safe and simple wherever nothing
--     else is ever appended to `parent` after our own children (true for
--     stroke blocks under OUR OWN dialog).
--   * delete_ui_child_by_handle: searches for the child's exact index by
--     identity first. Slower and depends on equality working, but it's
--     the only option where position can't be assumed -- specifically
--     deleting OUR dialog from the SHARED screen overlay, where other
--     open dialogs may sit after ours. If equality fails there, we
--     degrade to doing nothing rather than risk the alternative (deleting
--     "whatever is last"), which could destroy someone else's window --
--     forbidden by the safety contract, worse than a lingering handle.
-- ---------------------------------------------------------------------

-- try_get_ui_children_count / try_get_ui_child: same dual-attempt +
-- diagnostics pattern as try_delete below, applied to the COUNT/INDEX
-- lookups themselves. Ground truth (2026-07-17): a real System Monitor
-- diag showed `GetUIChildrenCount(ui.overlay)` returning nil -- the count
-- call itself was failing, which meant every deletion attempt downstream
-- (including stroke-block cleanup on Restart) was silently bailing out
-- before ever reaching try_delete, with NO log line, because the earlier
-- version of this code only diagnosed try_delete's internals, not the
-- count/lookup calls that gate it. `GetUIChildrenCount`/`GetUIChild` are
-- documented as bare globals (same HelpLua dump, same "no Handle: prefix"
-- format as `Delete`, which turned out to need BOTH forms tried) so the
-- same bare-global-then-colon fallback applies here too.
local function try_get_ui_children_count(parent, ctx)
    local ok1, val1 = pcall(GetUIChildrenCount, parent)
    if ok1 and val1 ~= nil then
        return val1
    end
    if not ok1 then
        diag(ctx .. ": GetUIChildrenCount(parent) errored: " .. tostring(val1))
    end
    local ok2, val2 = pcall(function()
        return parent:GetUIChildrenCount()
    end)
    if ok2 and val2 ~= nil then
        return val2
    end
    if not ok2 then
        diag(ctx .. ": parent:GetUIChildrenCount() errored: " .. tostring(val2))
    end
    diag(ctx .. ": both GetUIChildrenCount forms failed/returned nil")
    return nil
end

local function try_get_ui_child(parent, index, ctx)
    local ok1, val1 = pcall(GetUIChild, parent, index)
    if ok1 and val1 ~= nil then
        return val1
    end
    if not ok1 then
        diag(ctx .. ": GetUIChild(parent, " .. index .. ") errored: " .. tostring(val1))
    end
    local ok2, val2 = pcall(function()
        return parent:GetUIChild(index)
    end)
    if ok2 and val2 ~= nil then
        return val2
    end
    if not ok2 then
        diag(ctx .. ": parent:GetUIChild(" .. index .. ") errored: " .. tostring(val2))
    end
    return nil
end

-- Attempt to delete child `index` of `parent`, trying colon-method form
-- first, then bare-global form. Logs each failure via diag() so a System
-- Monitor screenshot can distinguish "function doesn't exist" from
-- "called fine, had no effect." Returns true only on a confirmed count
-- decrease.
local function try_delete(parent, index)
    local before = try_get_ui_children_count(parent, "try_delete")
    if before == nil then
        return false
    end

    local ok1, err1 = pcall(function()
        parent:Delete(index)
    end)
    if not ok1 then
        diag("try_delete: parent:Delete(" .. index .. ") errored: " .. tostring(err1))
    end
    local after1 = try_get_ui_children_count(parent, "try_delete (after colon)") or before
    if after1 < before then
        return true
    end

    local ok2, err2 = pcall(function()
        Delete(parent, index)
    end)
    if not ok2 then
        diag("try_delete: Delete(parent, " .. index .. ") errored: " .. tostring(err2))
    end
    local after2 = try_get_ui_children_count(parent, "try_delete (after global)") or before
    if after2 < before then
        return true
    end

    diag("try_delete: both colon and global Delete left count at " .. before ..
        " for index " .. index .. " -- deletion is not taking effect")
    return false
end

local function delete_last_ui_child(parent)
    if parent == nil then
        return false
    end
    local before = try_get_ui_children_count(parent, "delete_last_ui_child")
    if before == nil or before <= 0 then
        return false
    end
    return try_delete(parent, before)
end

local function delete_ui_child_by_handle(parent, child)
    if parent == nil or child == nil then
        return false
    end
    local before = try_get_ui_children_count(parent, "delete_ui_child_by_handle")
    local index = nil
    if before ~= nil then
        for i = 1, before do
            if try_get_ui_child(parent, i, "delete_ui_child_by_handle") == child then
                index = i
                break
            end
        end
    end
    if index == nil then
        diag("delete_ui_child_by_handle: handle not found among " ..
            tostring(before) .. " children -- equality lookup failed")
        return false
    end
    return try_delete(parent, index)
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
-- Letter text is the GUARANTEED baseline. Confirmed on-console (2026-07-16)
-- twice over: assigning Texture a raw guessed icon NAME string ("object_
-- light"/"object_audio") makes MA3 try to resolve it as an object address
-- and breaks silently; separately, emoji glyphs in Text never appeared even
-- though board state was tracking correctly, most likely a font gap. Both
-- failures are invisible to safe_set's pcall+read-back check. Plain ASCII
-- letters are the one form proven to render, so `Text` is ALWAYS set to the
-- letter first, unconditionally -- never removed, regardless of anything
-- below.
--
-- Real pool icons layer ON TOP of that baseline, best-effort.
--
-- First attempt (2026-07-16) used the show's custom Symbols pool item
-- names ("fixture1_png"/"user_png") -- FindTexture called fine (no error)
-- but found neither. Confirmed via System Monitor 2026-07-17.
--
-- Second attempt uses the CONSOLE'S OWN BUILT-IN library instead, per
-- exact file paths the user located and confirmed in the "Select Image for
-- Import" browser (Internal library, 2026-07-17):
--   lightbulb: C:/ProgramData/MALightingTechnology/gma3_2.4.2/shared/
--              resource/lib_symbols/object/fixture1.png
--   speaker:   C:/ProgramData/MALightingTechnology/gma3_2.4.2/shared/
--              resource/lib_symbols/executor/executor_learnspeed.png
-- Built-in stock icons are more likely to already be registered wherever
-- FindTexture actually searches than a show-specific custom pool item, so
-- several candidate string forms are tried, from most to least specific:
-- full absolute path, path relative to lib_symbols/, bare file name.
--
-- `FindTexture(string:texture_name): light_userdata:handle` is a documented
-- global (HelpLua dump) that resolves an EXISTING image to a real handle
-- -- read-only, nothing created or modified, same shape as the working
-- BackColor-via-theme-handle fix. If FindTexture returns nothing for any
-- candidate, or the Texture write itself fails, the letter underneath is
-- what the user sees -- there is no code path that can end with a blank
-- cell again.
-- =====================================================================

local SYMBOLS = {
    bulb = "L",
    speaker = "S",
}

-- ---------------------------------------------------------------------
-- Third approach (2026-07-17): FindTexture never matched any of five
-- distinct string forms tried across two rounds (custom pool item name,
-- three forms of a built-in library file path) despite calling fine every
-- time -- five misses with zero errors is a real signal that FindTexture
-- doesn't index by any guessable string at all, not just a naming miss.
--
-- The user's own question prompted a better approach: DON'T import or
-- string-match anything. The built-in symbols ("fixture1_png" at pool
-- index 38, "user_png" at index 41 -- confirmed via the pool editor
-- screenshots, 2026-07-16) already EXIST as real pool objects. Navigate to
-- them directly, the exact same proven way `resolve_stroke_color` already
-- reaches `Root().ColorTheme.ColorGroups.Global` successfully (dot-path
-- navigation off Root(), then `:Count()`/`:Ptr(index)` -- the documented,
-- working generic Object API, not FindTexture). This is read-only: it
-- looks up an EXISTING object, nothing is imported, created, or modified,
-- same safety shape as the color fix.
--
-- Exact property path from Root() to the Symbols pool isn't confirmed
-- (unlike ColorTheme.ColorGroups.Global, which is proven), so several
-- plausible paths are tried defensively, most to least likely.
-- ---------------------------------------------------------------------

local SYMBOL_POOL_INDEX = {
    bulb = 38, -- fixture1_png
    speaker = 41, -- user_png
}

local function resolve_symbol_pool()
    local candidates = {
        function() return Root().Symbols end,
        function() return Root().DataPools.Symbols end,
        function() return Root().ShowData.Symbols end,
        function() return DataPool().Symbols end,
        function() return CurrentDataPool().Symbols end,
    }
    for _, get in ipairs(candidates) do
        local pool = nil
        local ok = pcall(function()
            pool = get()
        end)
        if ok and pool ~= nil then
            -- Verify it actually behaves like a pool (has a working Count).
            local count_ok, count = pcall(function()
                return pool:Count()
            end)
            if count_ok and count ~= nil and count > 0 then
                return pool
            end
        end
    end
    return nil
end

-- Resolved once per activation, lazily, and cached. nil entries mean "not
-- resolved" -- callers must not treat that as an error, just skip the
-- upgrade.
local icon_handles = {}
local symbol_pool = nil -- false once tried-and-failed, nil = not tried yet

local function resolve_icon(player)
    if icon_handles[player] ~= nil then
        return icon_handles[player]
    end

    if symbol_pool == nil then
        symbol_pool = resolve_symbol_pool() or false
        if symbol_pool == false then
            diag("resolve_icon: could not locate the Symbols pool via any candidate path")
        end
    end

    local found = nil
    if symbol_pool then
        local index = SYMBOL_POOL_INDEX[player]
        local ok, err = pcall(function()
            found = symbol_pool:Ptr(index)
        end)
        if not ok then
            diag("resolve_icon(" .. player .. "): pool:Ptr(" .. index .. ") errored: " .. tostring(err))
        elseif found == nil then
            diag("resolve_icon(" .. player .. "): pool:Ptr(" .. index .. ") returned nil")
        end
    end

    icon_handles[player] = found or false -- false = "tried, not found"
    return found
end

-- Apply a player's symbol to a cell button. Letter first, always; icon is a
-- best-effort visual upgrade layered on top, never a replacement path.
local function apply_symbol(cell, player)
    if cell == nil or player == nil then
        return
    end
    safe_set(cell, "Text", SYMBOLS[player])
    local icon = resolve_icon(player)
    if icon then
        safe_set(cell, "Texture", icon)
    end
end

local function clear_symbol(cell)
    if cell == nil then
        return
    end
    -- NO Texture-clearing. Confirmed the regression source (2026-07-17):
    -- clear_symbol runs on every empty cell, on every refresh, including
    -- the very first reset_game() before any move -- so an empty-string
    -- Texture assignment here rendered the WHOLE grid black from the
    -- moment the window opened. There is no verified-working way to clear
    -- a texture on this build, and nothing currently sets one successfully
    -- either (see resolve_icon), so there's nothing to clear.
    safe_set(cell, "Text", "")
end

-- =====================================================================
-- SECTION 5 -- SAMPLED-STROKE RENDERING + FALLBACK CHAIN
-- ---------------------------------------------------------------------
-- MA3 has no reliable arbitrary-rotation primitive, so we render an angled
-- (or bent) stroke by rasterizing the polyline into many small overlapping
-- axis-aligned blocks.
--
-- Blocks are DIRECT CHILDREN OF THE DIALOG, positioned in the same absolute
-- coordinate space as the 9 cells. This is deliberate. An earlier revision
-- parented them to a dedicated "StrokeLayer" container, which caused two
-- problems on-console (2026-07-16):
--   * sized to the full grid, the layer sat on top of the board and was a
--     prime suspect for occluding it;
--   * shrunk to W=0/H=0 to avoid that, it would instead clip every child
--     block -- i.e. the win line would render nothing at all.
-- Direct dialog children at absolute X/Y are the ONE layout mechanism
-- confirmed working on this build: the 9 cells use exactly that and their
-- 480x480 footprint is visible in on-console screenshots. So the stroke
-- uses the same mechanism. Teardown tracks handles in ui.stroke_blocks
-- instead of relying on a single parent delete.
--
-- Fallback chain (degrade SILENTLY, never error):
--   1. sampled stroke  (primary)
--   2. elbow bars      (axis-aligned rects through cell centers)
-- The winner banner text is NOT part of this chain: it always renders.
-- =====================================================================

-- Layout, all in the dialog's absolute coordinate space. Every child gets
-- explicit geometry derived from these -- nothing is left to default
-- placement (see the status-line note in SECTION 10).
--
-- GRID_Y was 40 and the grid visibly overlapped the title bar's close
-- button on-console (2026-07-16) -- the real title bar renders taller than
-- that guess allowed for. Bumped to 64 with a wider safety margin; DIALOG_H
-- is derived from the layout instead of a separate hardcoded number, so the
-- two can never drift out of sync again.
--
--   grid    : y  64 .. 544   (GRID_Y .. GRID_Y + GRID_PX)
--   status  : y 556 .. 596
--   restart : y 608 .. 656
--   dialog H = 672
local GRID_PX = 480 -- pixel size of the 3x3 grid area
local CELL_PX = GRID_PX / 3
local GRID_Y = 64 -- top of the grid, in dialog space (title-bar clearance)
local STATUS_Y = GRID_Y + GRID_PX + 12 -- directly under the grid
local STATUS_H = 40
local RESTART_Y = STATUS_Y + STATUS_H + 12 -- under the status line
local RESTART_H = 48
local DIALOG_W = GRID_PX + 80 -- grid plus side margin
local DIALOG_H = RESTART_Y + RESTART_H + 16 -- content height + bottom margin
local BLOCK_MIN = 8 -- block edge in px
local BLOCK_MAX_COUNT = 48 -- hard cap on total blocks

-- Convert a cell index to its pixel center in the DIALOG's coordinate space
-- (same space the cell buttons are laid out in).
local function cell_center_px(idx)
    local cx, cy = cell_center_units(idx)
    return cx * CELL_PX, cy * CELL_PX + GRID_Y
end

-- ---------------------------------------------------------------------
-- Stroke color, resolved ONCE, READ-ONLY, and entirely optional.
--
-- The on-console error "Could not resolve object address for 0.12,0.12,0.12,1"
-- is the engine saying BackColor wants an OBJECT ADDRESS, not an "r,g,b,a"
-- string. A color that ALREADY EXISTS in the show's color theme is such an
-- object, so referencing one is a pure read -- we look one up and reuse its
-- handle. We never call :Acquire() and never create/modify a color, so no
-- show data is mutated (that distinction is what makes this in-bounds where
-- the documented Acquire() recipe is not).
--
-- Blast radius is contained ON PURPOSE: the resolved color is applied ONLY
-- to stroke blocks, never to cells. If this still misbehaves on some build,
-- the worst case is an invisible win line -- the board itself cannot be
-- blanked by it, which is the failure we already paid for once.
-- ---------------------------------------------------------------------
local stroke_color = nil -- handle or nil; resolved lazily, never created

local function resolve_stroke_color()
    local found = nil
    pcall(function()
        local grp = Root().ColorTheme.ColorGroups.Global
        if grp == nil then
            return
        end
        local count = grp.Count and grp:Count() or 0
        -- Prefer a name that reads as a highlight; otherwise take the first
        -- color that exists. Names vary by build, so this is best-effort.
        local preferred = { "select", "highlight", "mark", "warn", "active" }
        local first = nil
        for k = 1, count do
            local col = grp:Ptr(k)
            if col ~= nil then
                first = first or col
                local name = tostring(col.Name or ""):lower()
                for _, want in ipairs(preferred) do
                    if name:find(want, 1, true) then
                        found = col
                        return
                    end
                end
            end
        end
        found = first
    end)
    return found
end

-- Apply the stroke color to one block, if we managed to resolve one.
-- Assigning the HANDLE (not a string) is the form shown to work in the MA3
-- community docs: `button.backcolor = <color object>`.
local function apply_stroke_color(obj)
    if obj == nil or stroke_color == nil then
        return
    end
    pcall(function()
        obj.BackColor = stroke_color
    end)
end

-- Place one small square block centered at (px, py) in dialog space.
-- Returns true on success. Purely additive to our own subtree.
local function place_block(px, py, size)
    if ui.dialog == nil then
        return false
    end
    local block = safe_append(ui.dialog, "Button")
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
    apply_stroke_color(block)
    ui.stroke_blocks[#ui.stroke_blocks + 1] = block
    return true
end

-- Strategy 1: rasterize the polyline (list of cell indices) into blocks.
local function render_sampled_stroke(path)
    if ui.dialog == nil or #path < 2 then
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
    if ui.dialog == nil or #path < 2 then
        return false
    end
    local any = false
    for seg = 1, #path - 1 do
        local x1, y1 = cell_center_px(path[seg])
        local x2, y2 = cell_center_px(path[seg + 1])
        local bar = safe_append(ui.dialog, "Button")
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
            safe_set(bar, "Text", "")
            safe_set(bar, "Enabled", false)
            apply_stroke_color(bar)
            ui.stroke_blocks[#ui.stroke_blocks + 1] = bar
            any = true
        end
    end
    return any
end

-- Tear down the stroke: delete every block we created. Stroke blocks are
-- always the temporally-last children appended to `ui.dialog` (nothing else
-- is appended to it after build_ui), so repeatedly deleting the current
-- last child removes exactly the blocks we made -- and sidesteps the
-- handle-equality issue entirely for this, the highest-frequency deletion
-- path (every restart, every win).
local function clear_stroke()
    local count = #ui.stroke_blocks
    for _ = 1, count do
        delete_last_ui_child(ui.dialog)
    end
    ui.stroke_blocks = {}
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
    -- 1 -> 2 fallback chain, silent degrade. If both fail (e.g. the dialog
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
    -- Own-subtree teardown ONLY: resolve our dialog's exact index among the
    -- overlay's children and delete that index. Never assumes "last child"
    -- here -- see the UI-child-deletion comment above for why that would be
    -- unsafe on a container other dialogs may also live in.
    delete_ui_child_by_handle(ui.overlay, ui.dialog)
    ui.overlay = nil
    ui.dialog = nil
    ui.status = nil
    ui.cells = {}
    ui.stroke_blocks = {}
    stroke_color = nil -- do not hold a handle across instances
    icon_handles = {} -- likewise for resolved icon texture handles
    symbol_pool = nil -- and the resolved Symbols pool handle
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

    -- Our owned root. We keep both handles: `dialog` for own-subtree
    -- teardown, and `overlay` (its parent) so that teardown can resolve
    -- dialog's exact index for deletion rather than guessing "last child" of
    -- a container other dialogs may also live in.
    local dialog = safe_append(overlay, "BaseInput")
    if dialog == nil then
        diag("could not append BaseInput; aborting build")
        return false
    end
    ui.overlay = overlay
    ui.dialog = dialog
    safe_set(dialog, "Name", "TicTacToe")
    safe_set(dialog, "W", DIALOG_W)
    safe_set(dialog, "H", DIALOG_H)
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
    --
    -- Geometry is set EXPLICITLY. It previously had none, and an unpositioned
    -- child appears to default to filling its parent: on-console the status
    -- text rendered dead-centre of the dialog, i.e. a full-size button laid
    -- over the board. Every child gets explicit X/Y/W/H for that reason.
    ui.status = safe_append(dialog, "Button")
    if ui.status ~= nil then
        safe_set(ui.status, "X", 0)
        safe_set(ui.status, "Y", STATUS_Y)
        safe_set(ui.status, "W", GRID_PX)
        safe_set(ui.status, "H", STATUS_H)
        safe_set(ui.status, "Text", status_text())
        safe_set(ui.status, "Enabled", false)
    end

    -- 3x3 grid of cell buttons. NO BackColor here -- see SECTION 4 comment;
    -- a raw "r,g,b,a" string on BackColor made MA3 try to resolve it as an
    -- object address and silently broke rendering (confirmed on-console).
    for idx = 1, 9 do
        local cell = safe_append(dialog, "Button")
        ui.cells[idx] = cell
        if cell ~= nil then
            -- Absolute layout. Confirmed working on-console: the resulting
            -- 480x480 grid footprint is visible in screenshots.
            safe_set(cell, "X", cell_col(idx) * CELL_PX)
            safe_set(cell, "Y", cell_row(idx) * CELL_PX + GRID_Y)
            safe_set(cell, "W", CELL_PX - 6)
            safe_set(cell, "H", CELL_PX - 6)
            wire_click(cell, "TttCell" .. idx)
        end
    end

    -- Resolve the win-stroke color once, read-only (see SECTION 5). May stay
    -- nil, in which case the stroke still renders, just uncolored.
    stroke_color = resolve_stroke_color()

    -- Restart button.
    local restart = safe_append(dialog, "Button")
    if restart ~= nil then
        safe_set(restart, "Text", "Restart")
        safe_set(restart, "X", 0)
        safe_set(restart, "Y", RESTART_Y)
        safe_set(restart, "W", GRID_PX)
        safe_set(restart, "H", RESTART_H)
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
