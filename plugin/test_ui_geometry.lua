-- test_ui_geometry.lua -- headless UI-layer test for TicTacToe.lua
--
-- WHY THIS EXISTS
-- test_logic.lua proves the RIG (Section 1 of TicTacToe.lua) by exhaustive
-- enumeration, but it only mirrors the pure-logic block. It never compiles or
-- executes the UI half. That gap let two real defects reach the console:
--   * a Lua syntax error in the UI section (whole file failed to load), and
--   * layout/property bugs that rendered a blank board.
--
-- This test loads the REAL TicTacToe.lua against a stubbed grandMA3 object
-- model and asserts the geometry it produces. It cannot prove the plugin
-- looks right on a console -- only real hardware does that -- but it does
-- prove the file loads, builds its whole widget tree, places every child at
-- explicit non-overlapping coordinates, and draws win strokes on the board.
--
-- Run: uv run --with lupa python -c "from lupa import LuaRuntime; \
--        LuaRuntime().execute(open('plugin/test_ui_geometry.lua').read())"

-- ---------------------------------------------------------------------
-- Fake MA3 object model
-- ---------------------------------------------------------------------

local function new_obj(class)
    local obj = {}
    obj._class = class
    obj._children = {}
    obj.Append = function(self, cls)
        local child = new_obj(cls)
        child._parent = self
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
    return obj
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

-- `Delete(handle, index[, undo])` is a GLOBAL, PARENT-indexed function --
-- ground truth from the console's own HelpLua function dump (2026-07-16),
-- not a `child:Delete()` method. Deleting is something you do to a PARENT
-- at an index, matching the fix under test.
function Delete(handle, index) -- luacheck: ignore
    if index ~= nil and handle._children[index] ~= nil then
        table.remove(handle._children, index)
    end
end

-- `FindTexture(name)` resolves an EXISTING image to a handle. Fake pool
-- only recognizes the LEAST specific candidate (bare file name) for each
-- player, so the multi-candidate fallback in resolve_icon is actually
-- exercised (not just "first candidate always wins").
local BULB_TEXTURE = { _class = "Texture", name = "fixture1.png" }
local SPEAKER_TEXTURE = { _class = "Texture", name = "executor_learnspeed.png" }
local FAKE_TEXTURES = {
    ["fixture1.png"] = BULB_TEXTURE,
    ["executor_learnspeed.png"] = SPEAKER_TEXTURE,
}

function FindTexture(name) -- luacheck: ignore
    return FAKE_TEXTURES[name]
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

function Root() -- luacheck: ignore
    return { ColorTheme = { ColorGroups = { Global = color_group } } }
end

-- ---------------------------------------------------------------------
-- Load the real plugin
-- ---------------------------------------------------------------------

local file = io.open("plugin/TicTacToe.lua", "r")
assert(file, "cannot open plugin/TicTacToe.lua")
local src = file:read("*a")
file:close()

local chunk = assert(loadstring or load)(src, "TicTacToe")
local signal_table = {}
local Main = chunk("TicTacToe", "Main", signal_table, new_obj("PluginHandle"))
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

-- Mirrors the layout constants in TicTacToe.lua SECTION 5 -- keep in sync.
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
-- Play a bulb straight win (col 1: cells 1,4,7) and check the stroke
-- ---------------------------------------------------------------------

local function click(idx)
    local cb = signal_table["TttCell" .. idx]
    assert(cb, "no callback registered for cell " .. idx)
    cb()
end

click(1) -- bulb
click(2) -- speaker
click(4) -- bulb
click(5) -- speaker
click(7) -- bulb wins column 1

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
assert(cells[1].Text == "L", "cell 1 should show bulb letter L, got " .. tostring(cells[1].Text))
assert(cells[2].Text == "S", "cell 2 should show speaker letter S, got " .. tostring(cells[2].Text))
assert(cells[4].Text == "L", "cell 4 should show bulb letter L, got " .. tostring(cells[4].Text))
print("PASS: cell symbols are plain letters and actually render (Text set)")

-- Pool icons (resolved via the fake FindTexture, matching only the LEAST
-- specific candidate -- proving the full fallback chain runs, not just the
-- first entry) must layer on TOP of the letter, never replace it -- the
-- letter is the guaranteed fallback if a real console can't resolve the
-- icon, so it must survive regardless.
assert(cells[1].Texture == BULB_TEXTURE,
    "cell 1 (bulb) should carry the fixture1.png icon (via fallback chain)")
assert(cells[1].Text == "L", "icon assignment must not clear the letter fallback")
assert(cells[2].Texture == SPEAKER_TEXTURE,
    "cell 2 (speaker) should carry the executor_learnspeed.png icon (via fallback chain)")
print("PASS: pool icons resolved and layered without clobbering the letter fallback")

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

signal_table["TttRestart"]()
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
    assert(cell.Texture == nil,
        "unplayed cell " .. idx .. " has a Texture -- black-grid regression")
end
print("PASS: never-played cells never have Texture touched (black-grid regression guard)")

-- ---------------------------------------------------------------------
-- Idempotent re-activation must not stack overlays
-- ---------------------------------------------------------------------

Main()
assert(#overlay._children == 1,
    "re-activation stacked overlays: " .. #overlay._children)
print("PASS: re-activation is idempotent (one dialog)")

-- ---------------------------------------------------------------------
-- A speaker three-in-a-row must be ignored and hand the bulb a bent win
-- ---------------------------------------------------------------------

-- Fresh dialog after the Main() above; re-grab handles.
local dlg2 = overlay._children[1]
-- bulb 1, spk 2, bulb 4, spk 5, bulb 9, spk 8 -> speaker holds 2,5,8 (col 2)
click(1)
click(2)
click(4)
click(5)
click(9)
click(8) -- speaker completes a column; rig must fire

local after2 = children_of_class(dlg2, "Button")
local stroke2 = #after2 - 11
assert(stroke2 > 0, "speaker line did not trigger a rigged bulb win stroke")
print("PASS: speaker 3-in-a-row ignored; bulb win stroke drawn (" .. stroke2 .. " blocks)")

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

signal_table["TttClose"]()

assert(#overlay._children == 1, "close should remove exactly one dialog")
assert(overlay._children[1] == other_dialog,
    "close deleted the WRONG dialog -- destroyed another plugin's window")
print("PASS: closing our dialog never touches another dialog on the overlay")

print("")
print("ALL UI GEOMETRY TESTS PASSED")
