-- test_classic_ui.lua -- headless test for TicTacToeClassic.lua
--
-- Loads the REAL TicTacToeClassic.lua against a stubbed grandMA3 object model
-- (same stubs as test_ui_geometry.lua) and asserts geometry, X/O letters, the
-- X/O icon import + AppearancePreview drawing, win strokes, the draw state,
-- restart, idempotent activation and the letter fallbacks. It ends with an
-- exhaustive enumeration of every legal game through the plugin's REAL
-- SECTION 1 logic, checked against the known tic tac toe totals.
--
-- Run: uv run --with lupa python -c "from lupa import LuaRuntime; \
--        LuaRuntime().execute(open('plugin/test_classic_ui.lua').read())"

-- ---------------------------------------------------------------------
-- Fake MA3 object model
-- ---------------------------------------------------------------------

-- Stand-in for whatever Texture value a fresh MA3 Button carries. Texture is
-- a widget's BACKGROUND frame on MA3; the plugin must never write it at all
-- (on-console 2026-09-26: an image handle there blanked the cell).
local DEFAULT_TEX = "default_button_texture"

local function new_obj(class)
    local obj = {}
    obj._class = class
    obj._children = {}
    obj.Append = function(self, cls)
        local child = new_obj(cls)
        child._parent = self
        if cls == "Button" then
            child.Texture = DEFAULT_TEX
        end
        self._children[#self._children + 1] = child
        return child
    end
    -- Generic Object API (show-data pools): Count()/Ptr(). Real plugin uses
    -- these ONLY for the read-only color-theme lookup, never for UI trees.
    obj.Count = function(self)
        return #self._children
    end
    obj.Ptr = function(self, idx)
        return self._children[idx]
    end
    -- Colon-method forms, matching the dual-attempt fallback in
    -- try_get_ui_children_count / try_get_ui_child (production code tries
    -- bare-global first, colon second). Present here so the fallback path
    -- itself is exercisable, even though the bare globals below succeed
    -- first in this stub.
    obj.GetUIChildrenCount = function(self)
        return #self._children
    end
    obj.GetUIChild = function(self, idx)
        return self._children[idx]
    end
    -- `Children()` -- the primary, better-evidenced tier tried first by
    -- try_get_children_table (github.com/MacTirney/GrandMA3-API-Documentation,
    -- 2026-07-17). Returns a real table, matching the documented example.
    obj.Children = function(self)
        return self._children
    end
    -- `parent:Delete(index)` -- the ONLY form try_delete calls now. Ground
    -- truth (2026-07-17): the bare-global form errored with "attempt to
    -- call a nil value" on the real console -- it does not exist there, so
    -- this stub no longer defines it either, matching reality.
    obj.Delete = function(self, idx)
        if idx ~= nil and self._children[idx] ~= nil then
            table.remove(self._children, idx)
        end
    end
    return obj
end

function Children(handle) -- luacheck: ignore
    return handle._children
end

local overlay = new_obj("ScreenOverlay")

-- Globals the plugin reads. It only ever READS these.
function Printf(msg) end -- luacheck: ignore

function GetFocusDisplay() -- luacheck: ignore
    return { ScreenOverlay = overlay }
end

function GetDisplayByIndex(_) -- luacheck: ignore
    return { ScreenOverlay = overlay }
end

-- Documented UI-child functions (distinct from the generic Object API's
-- Count()/Ptr() above, which are for show-data pools, not UI trees).
function GetUIChildrenCount(handle) -- luacheck: ignore
    return #handle._children
end

function GetUIChild(handle, index) -- luacheck: ignore
    return handle._children[index]
end

-- Fake color theme with a couple of named colors, mirroring the read-only
-- lookup the plugin does (Root().ColorTheme.ColorGroups.Global).
local function fake_color(name)
    local col = new_obj("Color")
    col.Name = name
    return col
end

local color_group = new_obj("ColorGroup")
color_group._children = { fake_color("Background"), fake_color("Selected") }

-- Fake icon files + Symbols pool (2026-09-26 file-based icons). The plugin
-- derives lib_symbols from Version(), checks FileExists() for the png AND its
-- .png.xml sidecar, and imports the xml once into ShowData().MediaPools.Symbols
-- (gated on GetChildClass() == "SymbolImage"). The knobs below let the
-- fallback section simulate missing files, a wrong-class pool, and a failed
-- Import().
local LIB = "C:/ProgramData/MALightingTechnology/gma3_2.4.2/shared/resource/lib_symbols"
local files_present = true
local import_succeeds = true
local pool_child_class = "SymbolImage"
local import_log = {}
local acquire_count = 0

function Version() -- luacheck: ignore
    return "2.4.2.2"
end

local KNOWN_FILES = {
    [LIB .. "/symbols/x_mark_black.png"] = true,
    [LIB .. "/symbols/x_mark_black.png.xml"] = true,
    [LIB .. "/symbols/outline_circle_black.png"] = true,
    [LIB .. "/symbols/outline_circle_black.png.xml"] = true,
}

function FileExists(path) -- luacheck: ignore
    return files_present and KNOWN_FILES[path] == true
end

local function new_symbols_pool()
    local pool = new_obj("Symbols")
    pool.GetChildClass = function()
        return pool_child_class
    end
    pool.Find = function(self, name)
        for _, chd in ipairs(self._children) do
            if chd.Name == name then
                return chd
            end
        end
        return nil
    end
    pool.Acquire = function(self)
        acquire_count = acquire_count + 1
        local img = self:Append("SymbolImage")
        img.Import = function(obj, dir, file_name)
            import_log[#import_log + 1] = { dir = dir, file = file_name }
            obj.Name = "from_xml" -- Import may reset the name; plugin renames after
            return import_succeeds
        end
        return img
    end
    return pool
end

local symbols_pool = new_symbols_pool()

function ShowData() -- luacheck: ignore
    return { MediaPools = { Symbols = symbols_pool } }
end

function Root() -- luacheck: ignore
    return { ColorTheme = { ColorGroups = { Global = color_group } } }
end

-- ---------------------------------------------------------------------
-- Load the real plugin
-- ---------------------------------------------------------------------

local file = io.open("plugin/TicTacToeClassic.lua", "r")
assert(file, "cannot open plugin/TicTacToeClassic.lua")
local src = file:read("*a")
file:close()

local chunk = assert(loadstring or load)(src, "TicTacToeClassic")
local signal_table = {}
local Main = chunk("TicTacToeClassic", "Main", signal_table, new_obj("PluginHandle"))
assert(type(Main) == "function", "plugin did not return a Main function")

Main()

-- ---------------------------------------------------------------------
-- Locate the built widgets
-- ---------------------------------------------------------------------

assert(#overlay._children == 1, "expected exactly one dialog on the overlay")
local dialog = overlay._children[1]
assert(dialog._class == "BaseInput", "dialog should be a BaseInput")

local function children_of_class(parent, cls)
    local out = {}
    for _, chd in ipairs(parent._children) do
        if chd._class == cls then
            out[#out + 1] = chd
        end
    end
    return out
end

local buttons = children_of_class(dialog, "Button")
-- status + 9 cells + restart = 11 buttons before any win stroke
assert(#buttons == 11, "expected 11 buttons pre-win, got " .. #buttons)

-- Mirrors the layout constants in TicTacToeClassic.lua SECTION 5 -- keep in sync.
local GRID_PX, CELL_PX, GRID_Y = 480, 160, 64

-- ---------------------------------------------------------------------
-- Assert: every child has explicit geometry and nothing overlaps the grid
-- ---------------------------------------------------------------------

local grid_top, grid_bottom = GRID_Y, GRID_Y + GRID_PX
local passed = 0

for _, btn in ipairs(buttons) do
    assert(btn.X ~= nil and btn.Y ~= nil, "a button has no explicit X/Y")
    assert(btn.W ~= nil and btn.H ~= nil, "a button has no explicit W/H")
    passed = passed + 1
end
print("PASS: all " .. passed .. " buttons have explicit geometry")

-- The 9 cells must tile the grid exactly.
local seen = {}
for _, btn in ipairs(buttons) do
    if btn.Y ~= nil and btn.Y >= grid_top and btn.Y < grid_bottom and btn.W == CELL_PX - 6 then
        seen[#seen + 1] = btn
    end
end
assert(#seen == 9, "expected 9 grid cells, found " .. #seen)
for _, cell in ipairs(seen) do
    assert(cell.X >= 0 and cell.X + cell.W <= GRID_PX, "cell escapes grid horizontally")
    assert(cell.Y >= grid_top and cell.Y + cell.H <= grid_bottom, "cell escapes grid vertically")
end
print("PASS: 9 cells tile the grid within bounds")

-- Status and restart must sit BELOW the grid, not on top of it.
local below = 0
for _, btn in ipairs(buttons) do
    if btn.W == GRID_PX then -- status and restart are full-grid-width
        assert(btn.Y >= grid_bottom, "a full-width widget overlaps the grid at y=" .. btn.Y)
        below = below + 1
    end
end
assert(below == 2, "expected status + restart below the grid, got " .. below)
print("PASS: status and restart sit below the grid, not over it")

-- Top clearance must be generous enough for a title bar + close button --
-- regression guard for the reported overlap (2026-07-16, GRID_Y was 40).
assert(grid_top >= 56, "top clearance too tight, risks overlapping the title bar close button: " .. grid_top)
print("PASS: grid has generous top clearance (" .. grid_top .. "px) for the title bar")

-- ---------------------------------------------------------------------
-- Play an X win (col 1: cells 1,4,7) and check the stroke
-- ---------------------------------------------------------------------

local function click(idx)
    local cb = signal_table["TtcCell" .. idx]
    assert(cb, "no callback registered for cell " .. idx)
    cb()
end

click(1) -- X
click(2) -- O
click(4) -- X
click(5) -- O
click(7) -- X wins column 1

local status_btn = nil
for _, btn in ipairs(buttons) do
    if btn.W == GRID_PX and btn.Enabled == false then
        status_btn = btn
    end
end
assert(status_btn and status_btn.Text == "X wins!",
    "status should read 'X wins!', got " .. tostring(status_btn and status_btn.Text))
print("PASS: X three-in-a-row wins; status reads 'X wins!'")

local after = children_of_class(dialog, "Button")
local stroke = #after - 11
assert(stroke > 0, "win produced no stroke blocks")
assert(stroke <= 48, "stroke exceeded the 48-block cap: " .. stroke)
print("PASS: straight win drew " .. stroke .. " stroke blocks (cap 48)")

-- Cells 1, 4, 7 (the winning column) must carry visible symbol text -- this
-- is the bug where moves registered internally but nothing appeared on the
-- board. Letters are the primary (not fallback) symbol; see SECTION 4.
local cells = {}
for _, btn in ipairs(buttons) do
    if btn.Y ~= nil and btn.Y >= grid_top and btn.Y < grid_bottom and btn.W == CELL_PX - 6 then
        cells[#cells + 1] = btn
    end
end
-- cells table is in append order = board index order (1..9)
assert(cells[1].Text == "X", "cell 1 should show X, got " .. tostring(cells[1].Text))
assert(cells[2].Text == "O", "cell 2 should show O, got " .. tostring(cells[2].Text))
assert(cells[4].Text == "X", "cell 4 should show X, got " .. tostring(cells[4].Text))
print("PASS: cell symbols are plain letters and actually render (Text set)")

-- Icons are imported from the on-disk files into the Symbols pool and layered
-- on TOP of the letter, never replacing it -- the letter is the guaranteed
-- fallback if a real console can't resolve the icon, so it must survive.
assert(#symbols_pool._children == 2,
    "expected exactly 2 imported pool entries, got " .. #symbols_pool._children)
local x_icon = symbols_pool:Find("TicTacToeClassic_x")
local o_icon = symbols_pool:Find("TicTacToeClassic_o")
assert(x_icon and o_icon, "imported entries must be named TicTacToeClassic_x/_o")
assert(symbols_pool:Find("TicTacToe_bulb") == nil, "must never create the rigged plugin's entries")
assert(import_log[1].dir == LIB .. "/symbols" and import_log[1].file == "x_mark_black.png.xml",
    "X imported from wrong file: " .. import_log[1].dir .. "/" .. import_log[1].file)
assert(import_log[2].dir == LIB .. "/symbols"
    and import_log[2].file == "outline_circle_black.png.xml",
    "O imported from wrong file: " .. import_log[2].dir .. "/" .. import_log[2].file)
assert(cells[1].Text == "X", "icon assignment must not clear the letter fallback")
print("PASS: icon files imported once each; letters still set underneath")

-- Icons are drawn by one AppearancePreview per occupied cell (the widget MA's
-- own image editor uses), laid inside that cell -- never via cell.Texture.
local function preview_at(idx)
    local cx = ((idx - 1) % 3) * CELL_PX
    local cy = math.floor((idx - 1) / 3) * CELL_PX + GRID_Y
    for _, prv in ipairs(children_of_class(dialog, "AppearancePreview")) do
        if prv.X ~= nil and prv.X > cx and prv.X < cx + CELL_PX
            and prv.Y > cy and prv.Y < cy + CELL_PX then
            return prv
        end
    end
    return nil
end
local previews = children_of_class(dialog, "AppearancePreview")
assert(#previews == 5, "expected 5 previews (one per played cell), got " .. #previews)
for _, idx in ipairs({ 1, 4, 7 }) do
    local prv = preview_at(idx)
    assert(prv and prv.Appearance == x_icon and prv.Visible == true,
        "cell " .. idx .. " should show the X icon via AppearancePreview")
    assert(prv.X + prv.W <= ((idx - 1) % 3 + 1) * CELL_PX, "preview escapes its cell")
end
for _, idx in ipairs({ 2, 5 }) do
    local prv = preview_at(idx)
    assert(prv and prv.Appearance == o_icon and prv.Visible == true,
        "cell " .. idx .. " should show the O icon via AppearancePreview")
end
for idx = 1, 9 do
    assert(cells[idx].Texture == DEFAULT_TEX, "cell " .. idx .. " Texture was written")
end
print("PASS: icons drawn via per-cell AppearancePreview; no cell Texture ever written")

-- Every stroke block must land on the board, on the winning column's centre.
local expected_x = 0.5 * CELL_PX -- column 1 centre = 80
local checked = 0
for i = 12, #after do
    local blk = after[i]
    local cx = blk.X + blk.W / 2
    local cy = blk.Y + blk.H / 2
    assert(math.abs(cx - expected_x) < 1.0,
        "stroke block off the winning column: x=" .. cx .. " expected " .. expected_x)
    assert(cy >= grid_top - 1 and cy <= grid_bottom + 1,
        "stroke block outside the grid vertically: y=" .. cy)
    checked = checked + 1
end
print("PASS: all " .. checked .. " stroke blocks lie on the winning line, inside the grid")

-- The stroke should have been colored from the read-only theme lookup.
local colored = 0
for i = 12, #after do
    if after[i].BackColor ~= nil then
        colored = colored + 1
    end
end
assert(colored == checked, "stroke blocks were not colored from the theme")
print("PASS: stroke blocks colored via read-only theme handle (" .. colored .. ")")

-- ---------------------------------------------------------------------
-- Restart must clear the stroke and the board
-- ---------------------------------------------------------------------

signal_table["TtcRestart"]()
local post = children_of_class(dialog, "Button")
assert(#post == 11, "restart left stroke blocks behind: " .. (#post - 11))
print("PASS: restart removed every stroke block")

-- Regression guard (2026-07-17): clear_symbol must NEVER touch Texture.
-- Doing so on every empty cell, on every refresh -- including cells never
-- played at all -- is what rendered the whole grid black from the moment
-- the window opened, before any move. Check cells that were never part of
-- the first game (3, 6, 8, 9): they were "cleared" at build time and again
-- at restart, exactly the original bug's trigger path, and must never have
-- had a Texture written.
for _, idx in ipairs({ 3, 6, 8, 9 }) do
    local cell = cells[idx]
    assert(cell.Texture == DEFAULT_TEX,
        "unplayed cell " .. idx .. " had its Texture changed -- black-grid regression")
end
print("PASS: never-played cells never have Texture touched (black-grid regression guard)")

-- Played cells (1, 2, 4, 5, 7) must drop their icon on Restart -- otherwise
-- old icons haunt the new board. Hidden previews are also shrunk to 0x0 so
-- they can never swallow a click on the now-empty cell underneath.
for _, prv in ipairs(children_of_class(dialog, "AppearancePreview")) do
    assert(prv.Visible == false and prv.Appearance == nil,
        "a preview still shows an icon after Restart")
    assert(prv.W == 0 and prv.H == 0, "a hidden preview still covers its cell")
end
for _, idx in ipairs({ 1, 2, 4, 5, 7 }) do
    assert(cells[idx].Text == "", "played cell " .. idx .. " kept its letter after Restart")
end
print("PASS: restart hides every icon preview and leaves cells clickable")

-- ---------------------------------------------------------------------
-- Idempotent re-activation must not stack overlays
-- ---------------------------------------------------------------------

Main()
assert(#overlay._children == 1,
    "re-activation stacked overlays: " .. #overlay._children)
print("PASS: re-activation is idempotent (one dialog)")

-- ---------------------------------------------------------------------
-- O can win too (classic rules): X 1, O 2, X 4, O 5, X 9, O 8 -> O holds
-- column 2 (2,5,8). The stroke must sit on column 2, not anywhere else.
-- ---------------------------------------------------------------------

-- Fresh dialog after the Main() above; re-grab handles.
local dlg2 = overlay._children[1]
click(1)
click(2)
click(4)
click(5)
click(9)
click(8) -- O completes column 2

local after2 = children_of_class(dlg2, "Button")
local stroke2 = #after2 - 11
assert(stroke2 > 0, "O's winning line drew no stroke")
for idx2 = 12, #after2 do
    local blk = after2[idx2]
    assert(math.abs(blk.X + blk.W / 2 - 1.5 * CELL_PX) < 1.0,
        "O stroke block off column 2")
end
local status2 = nil
for _, btn in ipairs(after2) do
    if btn.W == GRID_PX and btn.Enabled == false then
        status2 = btn
    end
end
assert(status2.Text == "O wins!", "status should read 'O wins!', got " .. tostring(status2.Text))
click(3) -- game over: further clicks must be ignored
assert(#children_of_class(dlg2, "Button") == #after2, "click after O's win changed the board")
print("PASS: O three-in-a-row wins on column 2; post-win clicks ignored (" .. stroke2 .. " blocks)")

-- Draw: X 1, O 2, X 3, O 5, X 4, O 6, X 8, O 7, X 9 -> full board, no line.
signal_table["TtcRestart"]()
for _, idx2 in ipairs({ 1, 2, 3, 5, 4, 6, 8, 7, 9 }) do
    click(idx2)
end
assert(#children_of_class(dlg2, "Button") == 11, "a draw must draw no stroke")
assert(status2.Text == "Draw!", "status should read 'Draw!', got " .. tostring(status2.Text))
print("PASS: full board with no line is a draw; status 'Draw!', no stroke")

-- The second activation placed both players again: it must REUSE the named
-- pool entries, never import a second copy into the show.
assert(acquire_count == 2 and #symbols_pool._children == 2,
    "re-activation imported again: acquires=" .. acquire_count ..
    " pool entries=" .. #symbols_pool._children)
print("PASS: re-activation reuses imported icons (no duplicate pool entries)")

-- ---------------------------------------------------------------------
-- SAFETY-CRITICAL: closing our dialog must NEVER touch another dialog
-- sharing the same screen overlay. This is what the safety contract
-- absolutely forbids (no ClearUIChildren, no destroying other windows).
-- The earlier bugfix moved dialog deletion from "assume last child" to
-- "search by handle identity" specifically to guarantee this -- prove it.
-- ---------------------------------------------------------------------

local other_dialog = overlay:Append("BaseInput")
other_dialog.Name = "SomeOtherPlugin"
assert(#overlay._children == 2, "setup: expected our dialog + one other")

signal_table["TtcClose"]()

assert(#overlay._children == 1, "close should remove exactly one dialog")
assert(overlay._children[1] == other_dialog,
    "close deleted the WRONG dialog -- destroyed another plugin's window")
print("PASS: closing our dialog never touches another dialog on the overlay")

-- ---------------------------------------------------------------------
-- Fallbacks: every failure mode must leave plain X/O letters and a clean pool
-- ---------------------------------------------------------------------

-- Fresh plugin instance on a fresh overlay + pool, under the current knobs.
-- Plays X on 1, O on 2 and returns those two cell buttons.
local function run_fresh_instance()
    overlay = new_obj("ScreenOverlay")
    symbols_pool = new_symbols_pool()
    local fresh_signals = {}
    local fresh_main = chunk("TicTacToeClassic", "Main", fresh_signals, new_obj("PluginHandle"))
    fresh_main()
    fresh_signals["TtcCell1"]()
    fresh_signals["TtcCell2"]()
    local fresh_cells = {}
    for _, btn in ipairs(children_of_class(overlay._children[1], "Button")) do
        if btn.W == CELL_PX - 6 then
            fresh_cells[#fresh_cells + 1] = btn
        end
    end
    return fresh_cells[1], fresh_cells[2]
end

local function assert_letters_only(label)
    local x_cell, o_cell = run_fresh_instance()
    assert(x_cell.Text == "X" and o_cell.Text == "O", label .. ": letters missing")
    assert(x_cell.Texture == DEFAULT_TEX and o_cell.Texture == DEFAULT_TEX,
        label .. ": a cell Texture was changed without an icon")
    assert(#children_of_class(overlay._children[1], "AppearancePreview") == 0,
        label .. ": an icon preview was created without an icon")
    assert(#symbols_pool._children == 0,
        label .. ": pool left with " .. #symbols_pool._children .. " entries")
    print("PASS: " .. label .. " -> plain X/O letters, pool untouched")
end

-- MA3 installed elsewhere / icon files absent.
files_present = false
local acquires_before = acquire_count
assert_letters_only("icon files missing")
assert(acquire_count == acquires_before, "missing files must never Acquire a pool slot")

-- A resolvable root whose children aren't SymbolImage must never be written.
files_present = true
pool_child_class = "Sequence"
acquires_before = acquire_count
assert_letters_only("wrong-class pool")
assert(acquire_count == acquires_before, "wrong-class pool must never receive an Acquire")

-- Import() failing must remove the slot it just acquired.
pool_child_class = "SymbolImage"
import_succeeds = false
acquires_before = acquire_count
assert_letters_only("Import() failure")
assert(acquire_count > acquires_before, "setup: the failed-import path should have run")

-- ---------------------------------------------------------------------
-- Exhaustive rules check on the plugin's REAL SECTION 1 (not a mirror):
-- enumerate every legal game and compare with the well-known totals
-- (255168 games: 131184 X wins, 77904 O wins, 46080 draws).
-- ---------------------------------------------------------------------

local logic_start = src:find("-- SECTION 1 -- PURE GAME LOGIC", 1, true)
local logic_end = src:find("-- SECTION 2 -- UI STATE", 1, true)
assert(logic_start and logic_end, "cannot locate SECTION 1 in the plugin source")
local logic_src = src:sub(logic_start, logic_end - 1)
    .. "\nreturn resolve_after_move, new_board, other_player, PLAYER_X"
local resolve, fresh_board, next_player, first = assert((loadstring or load)(logic_src))()

local totals = { games = 0, x = 0, o = 0, draw = 0 }
local function explore(board, mover)
    for idx2 = 1, 9 do
        if board[idx2] == nil then
            board[idx2] = mover
            local res = resolve(board, mover)
            if res.over then
                totals.games = totals.games + 1
                if res.draw then
                    totals.draw = totals.draw + 1
                else
                    assert(res.winner == mover, "winner must be the player who just moved")
                    totals[mover] = totals[mover] + 1
                end
            else
                explore(board, next_player(mover))
            end
            board[idx2] = nil
        end
    end
end
explore(fresh_board(), first)
assert(totals.games == 255168, "games: " .. totals.games)
assert(totals.x == 131184, "X wins: " .. totals.x)
assert(totals.o == 77904, "O wins: " .. totals.o)
assert(totals.draw == 46080, "draws: " .. totals.draw)
print("PASS: all 255168 legal games -> 131184 X wins, 77904 O wins, 46080 draws")

print("")
print("ALL CLASSIC TESTS PASSED")
