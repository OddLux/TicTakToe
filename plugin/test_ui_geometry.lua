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
    obj._deleted = false
    obj.Append = function(self, cls)
        local child = new_obj(cls)
        child._parent = self
        self._children[#self._children + 1] = child
        return child
    end
    obj.Delete = function(self)
        self._deleted = true
        local parent = self._parent
        if parent then
            for idx, chd in ipairs(parent._children) do
                if chd == self then
                    table.remove(parent._children, idx)
                    break
                end
            end
        end
    end
    obj.Count = function(self)
        return #self._children
    end
    obj.Ptr = function(self, idx)
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

local GRID_PX, CELL_PX, GRID_Y = 480, 160, 40

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

print("")
print("ALL UI GEOMETRY TESTS PASSED")
