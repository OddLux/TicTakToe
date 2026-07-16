# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- Fix black-grid regression reported 2026-07-17: the whole 3x3 grid rendered
  solid black from the moment the window opened, no cells visible. Root
  cause -- `clear_symbol` (which runs on every empty cell, on every
  refresh, including the very first `reset_game()` before any move) had
  gained a `safe_set(cell, "Texture", "")` call when icon support was added
  last round. There is no verified-working way to clear a `Texture` on this
  build; assigning it an empty string is what turned every empty cell
  black. Removed. Nothing currently sets a texture successfully either
  (pending the `FindTexture` diagnostics below), so there was nothing to
  clear. `plugin/test_ui_geometry.lua` gained a regression guard: cells
  never played in a game must never have had `Texture` touched at all.

### Changed

- Instrument, rather than guess again, the two remaining silent failures
  (Restart not clearing the win line; pool icons not resolving). Both
  `Delete` and `FindTexture` calls are wrapped in `pcall`, which can hide
  a plain "attempt to call a nil value" error exactly as easily as it hides
  "called fine, had no effect" -- indistinguishable from System Monitor
  without added logging:
  - New `try_delete(parent, index)` attempts the colon-method form
    (`parent:Delete(index)`, matching how `Append`/`Count`/`Ptr` are proven
    to work via colon sugar on this build) and, if that doesn't reduce the
    child count, the bare-global form (`Delete(parent, index)`) as a second
    attempt. Every `pcall` failure and the final "neither worked" case are
    logged via the existing `diag()` helper, which reaches System Monitor
    as `[TicTacToe] ...` lines.
  - `resolve_icon` now distinguishes, via `diag()`, "`FindTexture` errored"
    (the function likely isn't callable as written) from "called fine,
    found neither candidate name" (the function works, the pool name guess
    is wrong) -- previously both cases looked identical (silent letter
    fallback).
  - This is diagnostic-only: the letter-first, texture-optional fallback
    behavior is unchanged. The payoff is the next System Monitor
    screenshot, which should finally show a decisive answer instead of
    another silent "still doesn't work."

### Added

- Real pool-icon symbols. Bulb cells layer the show's `fixture1_png`
  (lightbulb) texture on top of the `L` letter fallback; Speaker cells
  layer `user_png` (a person icon, confirmed intentional). Resolved
  read-only via the documented `FindTexture(name)` global -- no pool
  entries created or modified. The letter is ALWAYS set first and never
  cleared, so a console where the icon can't be resolved just shows the
  letter, never a blank cell.

### Fixed

- Fix Restart still not clearing the win line, and the grid overlapping the
  title bar's close button, both reported 2026-07-16. Root-caused against
  the console's own `HelpLua` function dump
  (`C:/ProgramData/MALightingTechnology/gma3_library/
  grandMA3_lua_functions.txt`), authoritative for this exact build:
  - `Delete` is a GLOBAL function, `Delete(handle, child_index[, undo])` --
    not a `handle:Delete(...)` colon method the way `Append`/`Count`/`Ptr`
    all work. The previous fix called it correctly shaped (parent + index)
    but via colon sugar, and separately relied on comparing handles
    returned by `GetUIChild` for equality to resolve which index to
    delete -- neither produced an error, but the deletion silently never
    happened, which is why the win line persisted through Restart. Now:
    stroke-block cleanup (the frequent, every-restart path) always targets
    the CURRENT LAST child by count, with no equality check at all, calling
    the documented global form directly. The rarer, safety-critical case
    (deleting our own dialog from the SHARED screen overlay, where other
    open dialogs must never be touched) keeps the identity-search strategy,
    since "last child" is unsafe to assume there.
  - `GRID_Y` (top clearance before the 3x3 grid) was 40px, visibly too
    tight for the real title bar. Bumped to 64px, and the dialog's overall
    `W`/`H` are now derived from the layout constants instead of separate
    hardcoded numbers, so the two can't drift out of sync again.
  - `plugin/test_ui_geometry.lua` gained coverage for all of this: a
    regression guard on minimum top clearance, and updated stubs for the
    real `Delete`/`FindTexture` global signatures so the deletion fix is
    exercised by the actual production code path, not just asserted by
    hand.

- Fix cell symbols never rendering and the win line surviving Restart, both
  found in on-console testing 2026-07-16 with an official grandMA3 2.3
  HelpLua function dump available for verification. Two separate root
  causes: (1) emoji glyphs never appeared even though moves registered
  correctly internally -- plain ASCII text (`"Restart"`, status line) does
  render, so the UI font most likely lacks emoji glyphs or chokes on the
  4-byte UTF-8 encoding; letters (`L`/`S`) are now the primary symbol, not a
  fallback. (2) every stroke-block deletion was failing, spamming System
  Monitor with hundreds of identical errors and leaving the win line on
  screen through Restart -- the HelpLua dump confirms object creation is
  PARENT-indexed (`Append(parent, class, undo, count)`), and the exact
  signature MA3 echoes back on a bad call matches a PARENT-indexed
  `Delete(parent, child_index, undo)`. The previous code called
  `child:Delete()` with no arguments, which is wrong for this API shape.
  Deletion is now resolved by searching for the child's exact index among
  its parent's children (`GetUIChildrenCount`/`GetUIChild`, the documented
  UI-tree functions, distinct from the generic Object API's `Count()`/
  `Ptr()` used elsewhere for the read-only color-theme lookup) rather than
  assuming "last child" -- required because the dialog's own parent is the
  SHARED screen overlay, where another open dialog could otherwise be
  destroyed by a wrong assumption. `plugin/test_ui_geometry.lua` gained a
  test that proves this directly: it places a second, unrelated dialog on
  the same fake overlay and asserts closing ours never touches it.

### Added

- Rigged Tic Tac Toe plugin for grandMA3 2.x (`plugin/TicTacToe.lua`,
  `plugin/TicTacToe.xml`). Two-player hot-seat game where the Lightbulb always
  wins and the Speaker can never win or draw. Includes a defensive,
  pcall-guarded MA3 UI, a sampled-stroke win-line renderer with an
  elbow-bar/cell-highlight fallback chain, `plugin/test_logic.lua` (exhaustive
  game-tree rig proof: 255168 games, speaker wins 0, draws 0, bulb 100%), and
  `docs/INSTALL.md`.

### Added

- `plugin/test_ui_geometry.lua` -- headless test for the UI layer, which
  previously had NO coverage at all (`test_logic.lua` only mirrors the pure
  game logic). It loads the real `TicTacToe.lua` against a stubbed grandMA3
  object model and asserts the widget tree it builds: every child has
  explicit geometry, the 9 cells tile the grid, status/restart sit below the
  board rather than over it, win strokes land on the winning line within the
  grid and respect the 48-block cap, restart clears them, re-activation is
  idempotent, and a speaker 3-in-a-row is ignored in favour of a bulb win.
  This gap is what let a Lua syntax error and the blank-board layout bugs
  reach the console.

### Fixed

- Correct a Lua syntax error in `plugin/TicTacToe.lua` (`stroke_layer:Count`
  method-index without a call) that would have prevented the plugin from
  loading in MA3. Now uses `.Count` for the existence check.
- Fix blank/non-rendering game window found in on-console testing (grandMA3
  2.3.0 onPC). System Monitor showed `Could not resolve object address for
  0.12,0.12,0.12,1` repeatedly at plugin load: assigning `BackColor`/
  `TextColor` a raw `"r,g,b,a"` string makes MA3 try to resolve it as an
  object address/handle, which silently breaks rendering of the widget.
  Removed all custom color assignments (the documented-safe alternative
  allocates a persistent color-pool entry in the show, which is out of
  bounds for this plugin's no-show-mutation contract); players are now
  distinguished by glyph/letter shape alone. Also replaced the unverified
  `"UIObject"` append class (status line, win-stroke layer) with `"Button"`,
  which is confirmed to render, and zeroed the win-stroke layer's own size so
  it can act as a coordinate anchor without risking occlusion of the grid.
- Fix cell symbols never appearing even after the color fix above. On-console
  testing showed a second round of `Could not resolve object address for
  object_light` / `object_audio` -- the guessed icon names used for the
  `Texture` property hit the same address-resolution failure as `BackColor`.
  This one was worse: the failure is asynchronous/engine-side, so
  `safe_set`'s pcall+read-back reported success and the icon->emoji->letter
  fallback cascade never reached the emoji tier, leaving cells with a broken
  texture and no text. Removed the icon/`Texture` attempt entirely; symbols
  now go straight to the emoji glyph (falling back to a plain letter),
  since `Text` is the one property confirmed to render correctly.
- Fix the win line (the plugin's centerpiece) never being visible, found by
  a full code audit. Three compounding defects: (a) the win-stroke layer had
  been shrunk to `W=0/H=0` to stop it occluding the board, which would
  instead have clipped every stroke block it parented; (b) with all custom
  color removed, gray blocks drawn on gray cells would have been invisible
  even unclipped; (c) the status line had no explicit geometry at all and
  appears to have defaulted to filling the dialog, laying a full-size button
  over the board. Stroke blocks are now direct children of the dialog at
  absolute coordinates -- the one layout mechanism confirmed working
  on-console (the cells use it) -- tracked in a handle list for teardown
  rather than via a parent container. Every child now gets explicit
  geometry from a single coherent layout block, with status and restart
  positioned below the grid.
- Restore win-line color safely. `Could not resolve object address` was the
  engine reporting that `BackColor` expects an object address; a color that
  already exists in the show's color theme is one. The plugin now looks up
  an existing theme color read-only and assigns its handle -- it never calls
  `:Acquire()` and never creates or modifies a color, so no show data is
  mutated. The lookup is applied ONLY to stroke blocks, so if it misbehaves
  on some build the worst case is an invisible line, never a blanked board.
