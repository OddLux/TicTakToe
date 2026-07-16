# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
