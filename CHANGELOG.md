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
