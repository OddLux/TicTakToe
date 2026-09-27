-- TicTacToeClassic.lua -- Classic Tic Tac Toe for grandMA3 2.x
--
-- Two-player hot-seat tic tac toe with standard rules: X moves first, three in
-- a row wins, a full board with no line is a draw. Sibling of the rigged
-- TicTacToe.lua -- same UI/icon machinery, fully independent (own callbacks,
-- own dialog, own Symbols pool entries). See docs/INSTALL.md and
-- plugin/test_classic_ui.lua.
--
-- SAFETY CONTRACT (non-negotiable, see the header comments through the file):
--   * No globals. Every symbol is `local`. We never write `_G` or monkeypatch
--     an MA3 global.
--   * No show-data mutation, with ONE user-approved exception: a one-time
--     Import() of the two icon files into the Symbols pool (SECTION 4).
--     There are ZERO Cmd() calls in this file.
--   * Every UI callback is wrapped in pcall -- a Lua error must never leak into
--     MA3's UI thread.
--   * We keep the handle to OUR BaseInput dialog and delete ONLY that on
--     teardown. We deliberately DO NOT call ClearUIChildren() on the screen
--     overlay (that would destroy other dialogs the user has open).
--   * Activation is idempotent: re-running closes any existing instance first.
--   * No timers, no network. File access is limited to FileExists() checks,
--     the icon Import() in SECTION 4, and -- only when missing -- writing
--     the icon's 4-line .png.xml sidecar next to its stock png (SECTION 4).
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
-- =====================================================================

local PLAYER_X = "x"
local PLAYER_O = "o"

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
    if player == PLAYER_X then
        return PLAYER_O
    end
    return PLAYER_X
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

local function board_full(board)
    for idx = 1, 9 do
        if board[idx] == nil then
            return false
        end
    end
    return true
end

-- Move resolution after `mover` places a mark. Classic rules:
--   { over = true, winner = mover, line = {a,b,c} }  -- mover completed a line
--   { over = true, draw = true }                     -- board full, no line
--   { over = false }                                 -- game continues
-- Only the mover can have just completed a line, so only the mover is checked.
local function resolve_after_move(board, mover)
    local line = winning_line(board, mover)
    if line then
        return { over = true, winner = mover, line = line }
    end
    if board_full(board) then
        return { over = true, draw = true }
    end
    return { over = false }
end

-- =====================================================================
-- SECTION 2 -- UI STATE  (in-memory only, no show data)
-- =====================================================================

-- Live game state. All file-scope locals; nothing global.
local game = {
    board = new_board(),
    current = PLAYER_X, -- X always moves first
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
    cell_previews = {}, -- idx -> AppearancePreview drawing that cell's icon
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
        Printf("[TicTacToeClassic] " .. tostring(msg))
    end)
    if not ok then
        pcall(function()
            print("[TicTacToeClassic] " .. tostring(msg))
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

-- try_get_ui_children_count / try_get_ui_child: multi-tier fallback for
-- enumerating a UI parent's children, from most to least evidenced.
--
-- Tier 1 -- `Children(handle)`: a documented Object API function (found in
-- a third-party API reference the user pointed to, 2026-07-17,
-- github.com/MacTirney/GrandMA3-API-Documentation) with an actual working
-- example (`mySequence:Children()` returning a table, iterated with
-- `#cues`/`cues[i]`). Stronger evidence than tier 2 below, which has never
-- had a confirmed-working example -- only documentation-format inference.
-- Colon form tried first per that doc's own stated convention ("omittable
-- with colon notation"), bare-global second.
--
-- Tier 2 -- `GetUIChildrenCount`/`GetUIChild`: the original approach. Kept
-- as fallback in case `Children()` doesn't exist on this build or doesn't
-- work on UI-tree handles specifically (the reference example used it on
-- a show-data Sequence, not a UI dialog -- unconfirmed whether it applies
-- here too). Ground truth (2026-07-17): a real System Monitor diag showed
-- `GetUIChildrenCount(ui.overlay)` returning nil -- the count call itself
-- was failing, which meant every deletion attempt downstream (including
-- stroke-block cleanup on Restart) was silently bailing out before ever
-- reaching try_delete, with no log line, because an earlier version of
-- this code only diagnosed try_delete's internals, not the count/lookup
-- calls that gate it.
--
-- Both tiers are logged via diag() on failure so the next System Monitor
-- screenshot shows exactly which (if any) tier actually works.

local function try_get_children_table(parent, ctx)
    local ok1, val1 = pcall(function()
        return parent:Children()
    end)
    if ok1 and val1 ~= nil then
        return val1
    end
    if not ok1 then
        diag(ctx .. ": parent:Children() errored: " .. tostring(val1))
    end
    local ok2, val2 = pcall(Children, parent)
    if ok2 and val2 ~= nil then
        return val2
    end
    if not ok2 then
        diag(ctx .. ": Children(parent) errored: " .. tostring(val2))
    end
    return nil
end

local function try_get_ui_children_count(parent, ctx)
    local children = try_get_children_table(parent, ctx)
    if children ~= nil then
        return #children
    end

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
    diag(ctx .. ": Children() and both GetUIChildrenCount forms failed/returned nil")
    return nil
end

local function try_get_ui_child(parent, index, ctx)
    local children = try_get_children_table(parent, ctx)
    if children ~= nil and children[index] ~= nil then
        return children[index]
    end

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

-- Attempt to delete child `index` of `parent` via colon-method form.
-- Ground truth (2026-07-17, real System Monitor capture): the bare-global
-- form `Delete(parent, index)` errors with "attempt to call a nil value
-- (global 'Delete')" -- it does not exist as a bare global on this build,
-- despite the HelpLua dump listing it without a "Handle:" prefix (the same
-- misleading formatting `Append`/`Count`/`Ptr` have, where colon form IS
-- correct). No longer attempted; this was proven dead, not just unverified.
-- Logs via diag() if the colon call itself errors or has no effect, so a
-- System Monitor screenshot can distinguish the two.
local function try_delete(parent, index)
    local before = try_get_ui_children_count(parent, "try_delete")
    if before == nil then
        return false
    end

    local ok, err = pcall(function()
        parent:Delete(index)
    end)
    if not ok then
        diag("try_delete: parent:Delete(" .. index .. ") errored: " .. tostring(err))
    end
    local after = try_get_ui_children_count(parent, "try_delete (after)") or before
    if after < before then
        return true
    end

    diag("try_delete: parent:Delete(" .. index .. ") left count at " .. before ..
        " -- deletion is not taking effect")
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
-- Letter text is the GUARANTEED baseline. Confirmed on-console (2026-07-16):
-- raw guessed icon-name strings on Texture break silently, and emoji glyphs
-- in Text never render (font gap). Plain ASCII letters are the one form
-- proven to render, so `Text` is ALWAYS set to the letter first,
-- unconditionally -- never removed, regardless of anything below.
--
-- Real icons layer ON TOP of that baseline, best-effort, sourced from the
-- console's own stock image files on disk (user-specified, 2026-09-26):
--   <MA data root>/gma3_<X.Y.Z>/shared/resource/lib_symbols/symbols/
--       x_mark_black.png          (X)
--       outline_circle_black.png  (O)
-- <X.Y.Z> comes from the running Version(), so a console only ever reads its
-- own version's files. If MA3 lives somewhere else, or the files are
-- missing, nothing is imported and the X/O letters stay.
--
-- Same mechanism the rigged TicTacToe.lua proved on-console (2026-09-26): a
-- one-time Import() into the show's Symbols pool (user-approved exception to
-- the no-mutation contract). Bounds on that exception:
--   * Only when the .png exists on disk. Import() reads its .png.xml
--     sidecar (the XML object description, which points at the png), but
--     stock installs do NOT ship sidecars: MA's own Import Image dialog
--     (lib_menus/ui/editors/image_import.lua) writes one the first time a
--     png is imported by hand. The dev machine only had them because of a
--     manual import on 2026-07-16; a fresh PC showed "not found" (2026-09-27).
--     So a missing sidecar is written once, byte-for-byte in MA's own format
--     (BOM, DataVersion = Version()). An existing sidecar is never touched.
--   * Only into a collection whose GetChildClass() is "SymbolImage" -- a
--     wrong root path can never receive an Acquire().
--   * Idempotent across activations: imported entries are named
--     "TicTacToeClassic_x"/"TicTacToeClassic_o" and found by name first, so
--     a show gets at most one entry per player, ever. Distinct from the
--     rigged plugin's entries; the two never share or touch each other's.
--   * A failed import removes the slot it just acquired.
-- No Cmd() anywhere; this is still the only show-data write in the file.
-- =====================================================================

local SYMBOLS = {
    x = "X",
    o = "O",
}

local MA_DATA_ROOT = "C:/ProgramData/MALightingTechnology"

local ICON_FILES = {
    x = { subdir = "symbols", file = "x_mark_black.png" },
    o = { subdir = "symbols", file = "outline_circle_black.png" },
}

local ICON_POOL_NAMES = {
    x = "TicTacToeClassic_x",
    o = "TicTacToeClassic_o",
}

-- Pool child class taken from the sidecar XML itself
-- (<SymbolImage FileName="x_mark_black.png" FilePath="symbols"/>).
local SYMBOL_CLASS = "SymbolImage"

-- Candidate paths to the Symbols pool, most to least likely. The console
-- addresses these images as "Image 2.38" / "Image 2.41" (2026-07-17), which
-- reads as media pool 2 (Symbols), item 38 -- hence MediaPools first. Every
-- candidate must still pass the SymbolImage child-class gate before use.
local SYMBOL_POOL_CANDIDATES = {
    function() return ShowData().MediaPools.Symbols end,
    function() return Root().ShowData.MediaPools.Symbols end,
    function() return ShowData().MediaPools:Ptr(2) end,
    function() return Root().ShowData.MediaPools:Ptr(2) end,
    function() return Root().Symbols end,
    function() return DataPool().Symbols end,
}

-- Return the lib_symbols directory for the running MA3 version, or nil.
local function lib_symbols_dir()
    local ok, ver = pcall(Version)
    if not ok or type(ver) ~= "string" then
        diag("icons: Version() unavailable -- using letters")
        return nil
    end
    local short = ver:match("^(%d+%.%d+%.%d+)")
    if short == nil then
        diag("icons: unexpected Version() format '" .. ver .. "' -- using letters")
        return nil
    end
    return MA_DATA_ROOT .. "/gma3_" .. short .. "/shared/resource/lib_symbols"
end

local function file_exists(path)
    local ok, found = pcall(FileExists, path)
    return ok and found == true
end

-- Write the .png.xml sidecar MA's Import Image dialog would create for `spec`.
-- Returns true on success. Only called when the sidecar is missing.
local function write_sidecar(xml_path, spec)
    local ok, err = pcall(function()
        local handle = assert(io.open(xml_path, "wb"))
        handle:write("\239\187\191<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n",
            "<GMA3 DataVersion=\"", tostring(Version()), "\">\n",
            "    <SymbolImage FileName=\"", spec.file, "\" FilePath=\"",
            spec.subdir, "\"/>\n",
            "</GMA3>\n")
        handle:close()
    end)
    if not ok then
        diag("icons: could not write " .. xml_path .. ": " .. tostring(err))
        return false
    end
    diag("icons: wrote missing sidecar " .. xml_path)
    return true
end

-- Return dir, xml_name for a player's icon, or nil if the png is missing or
-- its sidecar is missing and can't be written.
local function find_icon_file(player)
    local base = lib_symbols_dir()
    if base == nil then
        return nil
    end
    local spec = ICON_FILES[player]
    local dir = base .. "/" .. spec.subdir
    local png = dir .. "/" .. spec.file
    local xml_name = spec.file .. ".xml"
    if not file_exists(png) then
        diag("icons: " .. png .. " not found -- using letters")
        return nil
    end
    local xml_path = dir .. "/" .. xml_name
    if not file_exists(xml_path) and not write_sidecar(xml_path, spec) then
        return nil
    end
    return dir, xml_name
end

-- Resolve the Symbols pool, accepting only a collection of SymbolImage.
local function resolve_symbols_pool()
    for _, get_pool in ipairs(SYMBOL_POOL_CANDIDATES) do
        local ok, pool = pcall(get_pool)
        if ok and pool ~= nil then
            local cls_ok, cls = pcall(function()
                return pool:GetChildClass()
            end)
            if cls_ok and cls == SYMBOL_CLASS then
                return pool
            end
        end
    end
    diag("icons: no Symbols pool (child class " .. SYMBOL_CLASS .. ") found")
    return nil
end

-- Find a pool child by exact Name. Find() first, then a Children() scan.
local function find_by_name(pool, name)
    local ok, found = pcall(function()
        return pool:Find(name)
    end)
    if ok and found ~= nil then
        return found
    end
    local children = try_get_children_table(pool, "find_by_name")
    for _, child in ipairs(children or {}) do
        local name_ok, child_name = pcall(function()
            return child.Name
        end)
        if name_ok and child_name == name then
            return child
        end
    end
    return nil
end

-- Remove `obj` from `pool` after a failed import, so no empty slot is left.
local function discard_pool_entry(pool, obj)
    local children = try_get_children_table(pool, "discard_pool_entry")
    for idx, child in ipairs(children or {}) do
        if child == obj then
            try_delete(pool, idx)
            return
        end
    end
    diag("icons: could not locate failed import slot to remove it")
end

-- Import a player's icon file into the Symbols pool, once per show.
local function import_icon(player)
    local dir, xml_name = find_icon_file(player)
    if dir == nil then
        return nil
    end
    local pool = resolve_symbols_pool()
    if pool == nil then
        return nil
    end

    local name = ICON_POOL_NAMES[player]
    local existing = find_by_name(pool, name)
    if existing ~= nil then
        return existing
    end

    local acq_ok, obj = pcall(function()
        return pool:Acquire()
    end)
    if not acq_ok or obj == nil then
        diag("icons: Acquire() on Symbols pool failed: " .. tostring(obj))
        return nil
    end
    local imp_ok, imported = pcall(function()
        return obj:Import(dir, xml_name)
    end)
    if not imp_ok or not imported then
        diag("icons: Import(" .. dir .. ", " .. xml_name .. ") failed: " ..
            tostring(imported))
        discard_pool_entry(pool, obj)
        return nil
    end
    -- Name AFTER import: the XML load may reset properties. The name is what
    -- makes later activations reuse this entry instead of importing again.
    safe_set(obj, "Name", name)
    diag("icons: imported " .. xml_name .. " as " .. name)
    return obj
end

-- Resolved once per activation, lazily, and cached. nil entries mean "not
-- resolved" -- callers must not treat that as an error, just skip the
-- upgrade.
local icon_handles = {}

local function resolve_icon(player)
    if icon_handles[player] ~= nil then
        return icon_handles[player]
    end
    local found = import_icon(player)
    icon_handles[player] = found or false -- false = "tried, not found"
    return found
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
    -- Only a win has a line; a draw has none and draws no stroke.
    local path = outcome.line
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

-- ---------------------------------------------------------------------
-- Drawing the icon. NEVER via a cell's `Texture`: MA's own UI code
-- (gma3_2.4.2 lib_menus) uses Texture only for a widget's BACKGROUND FRAME
-- ("corner1", TextureCollect.Textures["frame15"]). Confirmed on-console
-- 2026-09-26: assigning the imported SymbolImage to Texture wiped the cell
-- background and drew no image -- the same failure as the 2026-07-17
-- black-grid bug (Texture = "").
--
-- MA's own image editor shows a pool image with an `AppearancePreview`
-- widget: `Frame.Preview.Appearance = target` (image_editor.lua), where
-- target is the image object itself. So each occupied cell gets one
-- AppearancePreview laid over it, created lazily the first time that cell
-- shows an icon and reused after. Lazy creation matters: nothing sits on top
-- of an empty cell unless it has held an icon, and a cleared preview is
-- hidden AND shrunk to 0x0 so it can't swallow the cell's clicks even if
-- `Visible` isn't honored. Previews are appended during play, before any
-- win stroke, so the stroke blocks stay the last children (clear_stroke
-- relies on that).
-- ---------------------------------------------------------------------
local ICON_INSET = 16 -- px of cell visible around the icon

local function show_icon_preview(idx, icon)
    local preview = ui.cell_previews[idx]
    if preview == nil then
        preview = safe_append(ui.dialog, "AppearancePreview")
        if preview == nil then
            diag("icons: could not append AppearancePreview for cell " .. idx)
            return
        end
        ui.cell_previews[idx] = preview
    end
    safe_set(preview, "X", cell_col(idx) * CELL_PX + ICON_INSET)
    safe_set(preview, "Y", cell_row(idx) * CELL_PX + GRID_Y + ICON_INSET)
    safe_set(preview, "W", CELL_PX - 6 - 2 * ICON_INSET)
    safe_set(preview, "H", CELL_PX - 6 - 2 * ICON_INSET)
    safe_set(preview, "Appearance", icon)
    safe_set(preview, "Visible", true)
end

local function hide_icon_preview(idx)
    local preview = ui.cell_previews[idx]
    if preview == nil then
        return
    end
    safe_set(preview, "Visible", false)
    safe_set(preview, "W", 0)
    safe_set(preview, "H", 0)
    -- Same clear MA uses itself (view_store_option.lua: `.Appearance = nil`).
    safe_set(preview, "Appearance", nil)
end

-- Apply a player's symbol to cell `idx`. Letter first, always; icon is a
-- best-effort visual upgrade layered on top, never a replacement path.
local function apply_symbol(idx, player)
    local cell = ui.cells[idx]
    if cell == nil or player == nil then
        return
    end
    safe_set(cell, "Text", SYMBOLS[player])
    local icon = resolve_icon(player)
    if icon then
        show_icon_preview(idx, icon)
    end
end

local function clear_symbol(idx)
    local cell = ui.cells[idx]
    if cell == nil then
        return
    end
    safe_set(cell, "Text", "")
    hide_icon_preview(idx)
end

-- =====================================================================
-- SECTION 6 -- VIEW SYNC
-- =====================================================================

local function status_text()
    if game.over then
        if game.outcome and game.outcome.draw then
            return "Draw!"
        end
        return SYMBOLS[game.outcome.winner] .. " wins!"
    end
    return SYMBOLS[game.current] .. "'s turn"
end

-- Reflect the whole game state onto the UI. Never raises.
local function refresh_view()
    pcall(function()
        safe_set(ui.status, "Text", status_text())
        for idx = 1, 9 do
            local owner = game.board[idx]
            if owner == nil then
                clear_symbol(idx)
            else
                apply_symbol(idx, owner)
            end
        end
    end)
end

-- =====================================================================
-- SECTION 7 -- GAME ACTIONS  (invoked by pcall-wrapped callbacks)
-- =====================================================================

local function reset_game()
    game.board = new_board()
    game.current = PLAYER_X
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
    ui.cell_previews = {}
    ui.stroke_blocks = {}
    stroke_color = nil -- do not hold a handle across instances
    icon_handles = {} -- likewise for resolved icon texture handles
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
        signalTable["TtcCell" .. idx] = guarded(function()
            do_move(idx)
        end)
    end
    signalTable["TtcRestart"] = guarded(reset_game)
    signalTable["TtcClose"] = guarded(teardown)
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
    safe_set(dialog, "Name", "TicTacToeClassic")
    safe_set(dialog, "W", DIALOG_W)
    safe_set(dialog, "H", DIALOG_H)
    safe_set(dialog, "AutoClose", false)
    safe_set(dialog, "CloseOnEscape", true)

    -- Title bar with a close button.
    local title_bar = safe_append(dialog, "TitleBar")
    if title_bar ~= nil then
        safe_set(title_bar, "Text", "Tic Tac Toe (Classic)")
        local close_btn = safe_append(title_bar, "CloseButton")
        if close_btn ~= nil then
            wire_click(close_btn, "TtcClose")
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
            wire_click(cell, "TtcCell" .. idx)
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
        wire_click(restart, "TtcRestart")
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
