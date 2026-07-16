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
