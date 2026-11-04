# TicTakToe

Two novelty Tic Tac Toe plugins for **grandMA3 2.x**: a hot-seat game that runs as a
screen overlay.

## Download

| Plugin | Game | Download |
|--------|------|----------|
| **TicTacToe (Rigged)** | Lightbulb vs. Speaker. The Lightbulb always wins. | [TicTacToe-Rigged.zip](https://github.com/OddLux/TicTakToe/releases/latest/download/TicTacToe-Rigged.zip) |
| **TicTacToe Classic** | Standard rules. X moves first, draws are possible. | [TicTacToe-Classic.zip](https://github.com/OddLux/TicTakToe/releases/latest/download/TicTacToe-Classic.zip) |

Each zip holds a Windows pair and a macOS pair (`...Mac.xml` + `...Mac.lua`), plus
the install guide. The macOS variants have only been tested with a mocked `GetPath()`,
not on a real Mac.

This repo is private, so you must be signed in to GitHub with access to it for the
links to work.

## Install

1. Unzip and copy the `.xml` and `.lua` for your platform into
   `gma3_library/datapools/plugins/`. Keep them in the same folder.
2. Open the Plugins pool, select an empty cell and **Import** the `.xml`.
3. Tap the imported plugin to play.

Full details, including troubleshooting and uninstalling, are in
[docs/INSTALL.md](docs/INSTALL.md).
