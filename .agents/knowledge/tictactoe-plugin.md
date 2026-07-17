---
topic: tictactoe-plugin
area: plugin/TicTacToe.lua
tickets: []
updated: 2026-07-17
---

# Rigged Tic Tac Toe Plugin (grandMA3)

A Lua plugin for grandMA3 2.x: two-player hot-seat tic tac toe in a closable
console dialog, where the "Lightbulb" player always wins (no draws, no
speaker wins, ever) regardless of what either player actually plays. No
formal ticket was ever registered for this work despite branch names using
a `dp-001` placeholder — `.tickets/BACKLOG.md` is empty and no
`.tickets/open/dp-001*` file exists.

**No ticket was ever created for this work** — branches use `dp-001` as a
placeholder name only; treat that as cosmetic, not a real ticket reference.

## Status at a glance

| Area | State |
|------|-------|
| Rig logic (bulb always wins) | **Proven correct.** Exhaustive headless harness: 255,168 legal games, 0 speaker wins, 0 draws, 100% bulb wins. |
| Window open/close, title bar | **Confirmed working on-console.** |
| 9-cell grid, letter symbols (`L`/`S`) | **Confirmed working on-console.** This is the reliable baseline — never remove it in favor of an untested upgrade. |
| Win-line rendering + color | **Confirmed working on-console** (a diagonal win produced a visible colored line). |
| Layout (grid vs title bar / close button) | **Believed fixed**, not independently re-confirmed after the `GRID_Y` bump to 64px. |
| **Restart not clearing the win line** | **Still broken as of 2026-07-17.** See "Open bug 1" below — this is the priority. |
| Pool icons (real bulb/speaker images instead of letters) | **Not working, actively being pursued.** See "Open bug 2" below. Cosmetic only; letters already work. |

## How it works

### Game logic (headless, no MA3 dependency)

Section 1 of `TicTacToe.lua` is pure Lua with zero UI calls, mirrored
exactly in `plugin/test_logic.lua` for exhaustive testing. Move resolution,
in order, after each mark is placed:

1. Bulb placed and now has a straight line → **honest win**, straight
   stroke.
2. Speaker placed and now has a straight line → **ignored entirely**; bulb
   wins immediately via a bent stroke through 3 of its own cells.
3. Board full, no bulb line → bulb wins via bent stroke.
4. Otherwise → turn passes, continue.

The rig can never fail to fire in time: bulb moves on turns 1/3/5/7/9, so
by the time a speaker could complete a line (move 6 at the earliest) the
bulb already has ≥3 cells to draw a line through. `test_logic.lua`
enumerates every legal game and asserts this invariant directly rather than
trusting the reasoning.

### Bent-path selection

When the winning line isn't a real straight line (rig fired via rule 2 or
3), the bulb's cells are scored to find the best-looking 3-cell path:
collinear triples are strongly preferred (rendered as a single straight
segment, indistinguishable from an honest win); otherwise a 2-segment
polyline is chosen, penalizing sharp turns.

### UI construction

`ScreenOverlay:Append("BaseInput")` builds the dialog; a `TitleBar` with a
`CloseButton`, a status line, 9 cell `Button`s, and a `Restart` button are
appended as direct children with **explicit absolute X/Y/W/H on every
single one** — nothing is left to default placement (an early bug had the
status line with no geometry at all, which rendered as a full-dialog-size
button covering the whole board).

### The win-line ("sampled stroke")

MA3 has no reliable arbitrary-rotation UI primitive, so an angled line is
faked by rasterizing the 1-2 segment path into up to 48 small square
`Button`s placed along it via linear interpolation. Fallback chain (silent
degrade, never errors): sampled stroke → axis-aligned elbow bars → nothing
(banner text always renders regardless, so the game stays legible even if
every stroke strategy fails).

## Key design choices (safety contract — do not relax these)

- **No `Cmd()` show-data mutation**, ever.
- **No `ClearUIChildren()` on the shared screen overlay.** It would destroy
  other dialogs the user has open. This is the single most likely way this
  plugin could break the console for real; a comment in the code says so —
  do not "fix" it back.
- **Own-subtree teardown only.** The dialog is deleted by resolving its
  *exact* index among the overlay's children by handle identity — never by
  assuming "delete the last child of the overlay," because another open
  dialog could be last. (Stroke blocks under our *own* dialog are the one
  place "delete the last child" is safe, since nothing else is ever
  appended there.)
- **Every callback wrapped in `pcall`.** A Lua error inside a click handler
  must never propagate into MA3's UI thread.
- **Letters (`L`/`S`) are the unconditional baseline**, not a fallback of
  last resort. `Text` is always set first, before any icon/texture attempt;
  nothing downstream is allowed to clear or replace it. This is why the
  game has stayed playable through every icon experiment below.
- **No `:Acquire()` for color** (would create a persistent color-pool entry
  — real show mutation) and **no `Import()` for icons** (would
  create/modify a pool entry on every activation, same problem). Both were
  considered and explicitly rejected; only read-only lookups of
  *already-existing* show objects are used (see the color and icon
  sections below).
- **Idempotent activation.** Re-running the plugin tears down any prior
  instance first; never stacks duplicate overlays.

## Ground truth source

The user's own console `HelpLua`-generated function dump —
`C:/ProgramData/MALightingTechnology/gma3_library/grandMA3_lua_functions.txt`
— is authoritative for their exact build and was decisive multiple times
this session, more reliable than the third-party GitHub mirror
(`JeremyDufeux/ma3-lua-api-for-vscode`) used early on before the local dump
was available. **If picking this work back up, read that file directly
before guessing at any MA3 API shape.**

Confirmed-real functions from that dump, with the calling-convention
gotcha noted below: `Append`, `Delete`, `Get`, `Count`, `Ptr`,
`GetUIChildrenCount`, `GetUIChild`, `UIChildren`, `FindTexture`, `Import`,
`Root`, `DataPool`, `CurrentDataPool`.

## Gotchas / non-obvious behavior

- **"No error" does not mean "it worked."** This tripped up nearly every
  round of this session. Observed failure classes that are silent to a
  `pcall` + read-back check:
  - A string property value gets treated as an object-address/handle
    lookup and fails asynchronously, engine-side, after the Lua call
    itself returns successfully (`BackColor` as a raw `"r,g,b,a"` string;
    `Texture` as a guessed icon name — both produced "Could not resolve
    object address for X" in System Monitor, but only later / indirectly).
  - Glyphs that don't exist in the console's UI font (tried emoji `💡`/`🔊`
    in `Text`) render as nothing, no error.
  - Calling a function with the wrong convention (colon-method vs bare
    global) when the *other* convention is the one that actually exists —
    calling a nil global raises "attempt to call a nil value", which a
    wrapping `pcall` swallows exactly as silently as a genuine no-op.
  - A count/lookup call earlier in a chain (`GetUIChildrenCount`) silently
    returning `nil` short-circuits everything downstream with **no log
    line**, if that specific call site wasn't instrumented — this bit the
    Restart-deletion path for at least one full round (see Open bug 1).
- **Documentation formatting does not reliably indicate calling
  convention.** The HelpLua dump lists `Append`, `Count`, `Ptr`, `Delete`,
  `GetUIChildrenCount`, `GetUIChild` all the same way — no `Handle:`
  prefix. `Append`/`Count`/`Ptr` are proven to work via colon sugar
  (`obj:Append(...)`) on this console anyway. `Delete` needed BOTH forms
  attempted (colon first, then bare global) before anything worked at all.
  **Never assume one calling convention from doc formatting alone — try
  both, and log which one (if either) actually took effect.**
- **Two distinct, non-interchangeable object APIs:**
  - Generic Object API (`Count(handle)` / `Ptr(handle, index)`) — for
    show-data pools (used for `Root().ColorTheme.ColorGroups.Global` and,
    as of the latest icon attempt, `Root().Symbols`).
  - UI-specific API (`GetUIChildrenCount(handle)` /
    `GetUIChild(handle, index)`) — for UI widget trees (dialog children,
    stroke blocks). Using the wrong one for the wrong kind of handle is an
    easy, silent mistake.
- **Assigning a resolved HANDLE (not a raw string) is the pattern that
  actually works** for both color and (attempted) icons. `BackColor` only
  started working once it was set to a real `Color` object handle read
  from `Root().ColorTheme.ColorGroups.Global` via `:Count()`/`:Ptr(k)`,
  never a raw `"r,g,b,a"` string.
- The Symbols-pool file browser (`Select Image for Import` dialog,
  "Internal" library) showed paths under `gma3_2.4.2`, while the console's
  own title bar in earlier screenshots read `onPC 2.3.2.0` — a version
  discrepancy that was never resolved or explained. Worth checking if
  future path-based guesses keep failing.

## Open bug 1: Restart doesn't clear the win line

**Symptom:** after a win, hitting Restart redraws a fresh board but the old
win-line stroke blocks stay visible on screen.

**Attempts, in order, all on the `try_delete`/`delete_last_ui_child` /
`delete_ui_child_by_handle` code path in `TicTacToe.lua`:**

1. `child:Delete()` (no args, called on the block itself) — wrong shape
   entirely; the real `Delete` signature is parent-indexed
   (`Delete(parent_handle, child_index, undo)`, confirmed in the HelpLua
   dump). This produced a wall of "returns nothing" errors in System
   Monitor for every single stroke block, every restart.
2. Switched to parent+index shape, called via colon
   (`parent:Delete(index)`) with the target index resolved by searching
   `GetUIChild(parent, i) == child` for equality — silently failed, zero
   errors, line still didn't clear. Suspected cause: handle equality
   across two separate calls isn't guaranteed for whatever handle
   representation this binding uses.
3. Added a bare-global attempt (`Delete(parent, index)`) as a fallback
   after the colon attempt, plus `diag()` logging on every `pcall`
   failure — still failed, still no errors, confirmed by the user
   ("Line still remains after reset").
4. A System Monitor capture then showed `"handle not found among nil
   children"` — meaning `GetUIChildrenCount(ui.overlay)` itself returned
   `nil`. This was the real breakthrough: the count/lookup calls that
   *gate* deletion were failing, and `delete_last_ui_child` (the function
   Restart's cleanup actually goes through) had never been instrumented to
   log that specific failure — so the whole chain was likely bailing out
   silently before `try_delete` was ever reached, on every prior round.
5. **Current state (untested on console):** `GetUIChildrenCount`/
   `GetUIChild` now get the same dual-attempt treatment as `Delete`
   (bare-global first, then colon-method), via new
   `try_get_ui_children_count`/`try_get_ui_child` helpers, with `diag()`
   logging at every failure point on every call site. This should either
   finally work, or produce a decisive System Monitor error explaining
   exactly why not.

**Next step if still broken:** get a fresh System Monitor screenshot right
after a Restart click and read the `[TicTacToe] ...` diagnostic lines —
they should now say specifically which of the 4 calling-convention
combinations (colon/global × GetUIChildrenCount/Delete) succeeded or
failed, rather than nothing at all.

## Open bug 2: Pool icons not resolving (cosmetic — letters already work)

**Symptom:** cells show `L`/`S` letters (this is fine/expected) instead of
the intended lightbulb/speaker pool images.

**Attempts, in order:**

1. Guessed a raw icon *name* string ("object_light"/"object_audio")
   directly as `Texture` — same object-address-resolution failure as the
   `BackColor` bug; broke silently (async, past `safe_set`'s read-back).
2. Emoji glyphs (`💡`/`🔊`) in `Text` — rendered as nothing, likely a font
   gap; abandoned in favor of plain letters, which do render.
3. `FindTexture(name)` (documented, real, callable-with-no-errors global)
   tried with the **show's custom Symbols pool item name**
   (`"fixture1_png"`/`"user_png"`, confirmed via the pool editor's own
   "Edit Symbols.SymbolImage" dialog) and separately its **File Name**
   field (`"fixture1.png"`/`"user.png"`) — found neither, no errors.
4. `FindTexture` tried again with the **console's built-in library** file
   paths instead (a different, more fundamental resource than the show's
   custom pool — found via the "Select Image for Import" browser,
   `lib_symbols/object/fixture1.png` and
   `lib_symbols/executor/executor_learnspeed.png`), in three string forms
   each (full absolute path, path relative to `lib_symbols/`, bare file
   name) — **all six missed, still zero errors.** Five total distinct
   `FindTexture` name/path guesses across two rounds, all misses, never a
   single error — strong evidence `FindTexture` doesn't index by any
   guessable string form at all, not just a naming mistake.
5. User asked directly: "can't the plugin import the symbols the same way
   datapools do." Investigated `Import(handle, file_path, file_name):
   boolean` (HelpLua dump, the literal function backing the pool editor's
   own Import button) — **rejected**, because calling it live would
   create/modify a pool entry on every plugin activation, which is real
   show-data mutation the plugin has avoided everywhere else.
6. **Current approach (untested on console):** the built-in symbols
   already **exist** as pool objects (`fixture1_png` at pool index 38,
   `user_png` at index 41 — visible directly in the pool editor
   screenshots). `resolve_icon` now navigates to them directly via
   `Root().Symbols:Ptr(38)` / `:Ptr(41)` — the exact same proven mechanism
   already working for the win-line color
   (`Root().ColorTheme.ColorGroups.Global`, same `Count()`/`Ptr()`
   pattern). Purely read-only. The exact property path from `Root()` down
   to the Symbols pool isn't confirmed (unlike `ColorTheme`, which is
   proven), so 5 candidate paths are tried defensively
   (`Root().Symbols`, `Root().DataPools.Symbols`, `Root().ShowData.Symbols`,
   `DataPool().Symbols`, `CurrentDataPool().Symbols`), each verified by a
   working `:Count()` before use, with `diag()` logging on failure.

**Next step if still not working:** System Monitor after opening the
plugin should show a `resolve_icon` diagnostic naming which (if any)
candidate path resolved, or that all five failed — that will tell us
whether the problem is the *path to the pool* or something deeper about
how `Texture` accepts a `SymbolImage`-class handle specifically (which has
never been confirmed compatible, unlike `Color`-class handles for
`BackColor`).

## Testing

- `plugin/test_logic.lua` — exhaustive pure-logic harness, no MA3 needed.
  Enumerates every legal game; asserts 0 speaker wins, 0 draws, 100% bulb
  wins, and the "≥3 bulb cells available whenever the rig fires" invariant.
  Run via `uv run --with lupa python -c "from lupa import LuaRuntime;
  LuaRuntime().execute(open('plugin/test_logic.lua').read())"`.
- `plugin/test_ui_geometry.lua` — loads the REAL `TicTacToe.lua` against a
  stubbed MA3 object model (fake `Append`/`Delete`/`GetUIChildrenCount`/
  `GetUIChild`/`FindTexture`/`Root()` etc., matching the exact calling
  conventions confirmed from the HelpLua dump). Asserts the full widget
  tree geometry, that letters actually render, that the win-line stroke
  lands on the winning cells and is colored, that Restart removes it, that
  re-activation is idempotent, and — safety-critical — that closing our
  dialog **never** deletes another dialog sharing the same overlay. This
  suite has caught real regressions before they reached the console (e.g.
  a black-grid bug from an errant `Texture=""` clear) and should be
  extended whenever a new API call is added, not just trusted to "probably
  still pass."
- Both suites currently pass. Neither can prove on-console visual
  correctness — that's what System Monitor screenshots from the user are
  for, and why every unverified change in this file is flagged as such.

## Related

- Main implementation: `plugin/TicTacToe.lua`
- Test harnesses: `plugin/test_logic.lua`, `plugin/test_ui_geometry.lua`
- Packaging: `plugin/TicTacToe.xml`, `docs/INSTALL.md`
- Ground truth API reference (user's machine, not in this repo):
  `C:/ProgramData/MALightingTechnology/gma3_library/grandMA3_lua_functions.txt`
- `CHANGELOG.md` has a detailed `[Unreleased]` entry per bugfix round —
  more granular blow-by-blow than this file, worth reading if this
  document doesn't answer a specific question.
