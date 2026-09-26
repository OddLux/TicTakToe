# Version 1.0.0

# TicTacToe (Rigged) -- Install & Run

A novelty two-player, hot-seat Tic Tac Toe plugin for **grandMA3 2.x**.
Player 1 is the **Lightbulb** (💡), Player 2 is the **Speaker** (🔊).

> The game is rigged: the **Lightbulb always wins**. The Speaker can never win
> and there is no draw. If the Speaker lands three in a row, the game ignores
> it and hands the win to the Lightbulb, drawing a strike line (bending across
> three Lightbulb cells when they are not in a straight line).

The plugin is deliberately conservative: its only show-data write is a
one-time import of two icons into the Symbols pool. It wraps
every UI callback so a Lua error cannot leak into the console, and tears down
only its own dialog. See "Safety" below.

---

## Files

```
plugin/
  TicTacToe.lua      -- the whole implementation (logic + UI)
  TicTacToe.xml      -- Plugins-pool wrapper that references TicTacToe.lua
  test_logic.lua     -- standalone headless rig proof (no MA3 needed)
  TicTacToeClassic.lua  -- classic (unrigged) variant, see below
  TicTacToeClassic.xml  -- Plugins-pool wrapper for the classic variant
  test_classic_ui.lua   -- headless test for the classic variant
docs/
  INSTALL.md         -- this file
```

### Classic variant (`TicTacToeClassic`)

A separate plugin with standard rules: **X** moves first, three in a row
wins (for either player), and a full board with no line is a **draw**. The
status line reads `X's turn` / `O's turn`, then `X wins!`, `O wins!` or
`Draw!`. The winning line is struck through; a draw has no strike.

Install it exactly like the rigged plugin, using `TicTacToeClassic.xml` +
`TicTacToeClassic.lua`. The two plugins are fully independent and can both
be in the pool at once.

**Symbols.** Every mark always shows the letter `X` or `O`. On top of that
it shows MA3's stock icons from the running version's install folder:

```
C:/ProgramData/MALightingTechnology/gma3_<version>/shared/resource/lib_symbols/symbols/x_mark_black.png
C:/ProgramData/MALightingTechnology/gma3_<version>/shared/resource/lib_symbols/symbols/outline_circle_black.png
```

They're imported once into the Symbols pool as `TicTacToeClassic_x` /
`TicTacToeClassic_o` and reused on later runs. Same rules as the rigged
plugin: if the files (or their `.png.xml` sidecars) are missing, or the import
fails, nothing is added to the show and the plain `X` / `O` letters are used.

Test it headless:
`uv run --with lupa python -c "from lupa import LuaRuntime; LuaRuntime().execute(open('plugin/test_classic_ui.lua').read())"`

---

## Install into the Plugins pool

1. **Copy both plugin files onto the console** (or onPC machine), keeping them
   together in the same folder. The standard location is the gma3 library
   plugins folder:

   ```
   .../gma3_library/datapools/plugins/TicTacToe.xml
   .../gma3_library/datapools/plugins/TicTacToe.lua
   ```

   On grandMA3 onPC (Windows) the library typically lives under:

   ```
   %USERPROFILE%\MALightingTechnology\gma3_library\datapools\plugins\
   ```

   The exact path can differ by build and by USB vs. internal drive -- use the
   path your console shows in the Plugins pool import browser.

2. **Open the Plugins pool.** `Menu` -> `Plugins` (or add a Plugins pool window
   to a screen).

3. **Import the plugin.** Select an empty Plugins pool cell, then use the pool's
   **Import** function and pick `TicTacToe.xml`. MA3 reads the `<ComponentLua>`
   entry and loads `TicTacToe.lua` from the same folder.

   - If import warns about `DataVersion`, edit the `DataVersion` attribute in
     `TicTacToe.xml` to match your console build (see `Help` > `About`) and
     re-import.
   - If MA3 reassigns the GUID, that is expected and harmless.

4. **Run it.** Tap/click the imported plugin pool object. The Tic Tac Toe
   window opens as a screen overlay.

---

## Playing

- The **status line** shows whose turn it is and, at the end, `Lightbulb wins!`.
- Tap a cell to place the current player's symbol. The Lightbulb always moves
  first; players alternate.
- **Restart** clears the board and the strike line.
- Close the window with the title-bar close button or `Esc`.

**Symbols.** Every mark always shows the letter `L` (Lightbulb) or `S`
(Speaker). On top of that, the plugin tries to show MA3's own stock icons,
read from the running version's install folder:

```
C:/ProgramData/MALightingTechnology/gma3_<version>/shared/resource/lib_symbols/object/fixture1.png
C:/ProgramData/MALightingTechnology/gma3_<version>/shared/resource/lib_symbols/executor/executor_learnspeed.png
```

The first time they're needed, each icon is imported once into the show's
Symbols pool as `TicTacToe_bulb` / `TicTacToe_speaker`. Later runs reuse those
entries. If MA3 is installed elsewhere, a file (or its `.png.xml` sidecar) is
missing, or the import fails, nothing is added to the show and the plain
letters are used. No configuration needed.

---

## Prove the rig yourself (headless, no MA3 required)

The game logic in `TicTacToe.lua` has zero UI dependency. `test_logic.lua`
mirrors that logic and enumerates **every legal game**, asserting the rig:

```
lua    plugin/test_logic.lua
lua5.4 plugin/test_logic.lua
luajit plugin/test_logic.lua
```

Expected output (numbers are exact):

```
games enumerated : 255168
bulb wins        : 255168
speaker wins     : 0
draws            : 0
...
PASS: speaker wins == 0, draws == 0, bulb wins == 100%
```

The harness also asserts the geometry invariants: at every rigged win there are
at least 3 Lightbulb cells available, the strike path uses 3 distinct cells with
at most one turn, and a collinear triple is always rendered as a single straight
segment when one is available.

> No Lua interpreter on the machine? Any of these gets you one:
> `winget install DEVCOM.LuaBinaries`, a LuaJIT build, or run it through the
> `lupa` Python package: `uv run --with lupa python -c "import lupa; lupa.LuaRuntime().execute(open('plugin/test_logic.lua').read())"`.

---

## Safety notes (why this is console-safe)

- **Minimal show-data mutation.** There are zero `Cmd()` calls in the plugin.
  The only write to the show is the one-time import of the two icons into
  the Symbols pool (see **Symbols** above). It only happens when the files
  exist, only targets a collection of `SymbolImage` objects, and never adds a
  second copy.
- **No globals.** Every symbol is `local`; the plugin never writes `_G`.
- **Callbacks are sandboxed.** Every click handler runs under `pcall`; a Lua
  error is swallowed and logged via `Printf`, never propagated into MA3's UI.
- **Own-subtree teardown only.** The plugin keeps the handle to its own dialog
  and deletes only that. It deliberately does **not** call `ClearUIChildren()`
  on the screen overlay -- doing so would destroy other windows you have open.
- **Idempotent.** Re-running closes any existing instance first, so overlays
  never stack.
- **No timers, no network, no disk writes.** File access is limited to
  `FileExists()` checks and reading the two icon files during import.

---

## Uninstall

Delete the plugin pool object (select the cell, `Delete`), then remove
`TicTacToe.xml` and `TicTacToe.lua` from the plugins folder if desired.
