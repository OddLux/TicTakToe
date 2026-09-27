---
topic: tictactoe-plugin
area: plugin/TicTacToe.lua
tickets: []
updated: 2026-09-26
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
| Restart clears the win line | **Confirmed working on-console, 2026-07-17.** No errors. Fixed by the `Children()` primary tier; see "Open bug 1 — RESOLVED" below for the full chain and one loose end. |
| Pool icons (real bulb/speaker images instead of letters) | **Confirmed working on-console, 2026-09-26** ("this version works"): file import plus `AppearancePreview` drawing. See "Open bug 2", steps 9-10. Cosmetic only; letters already work. |

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
- **No `:Acquire()` for color** (would create a persistent color-pool entry,
  which is real show mutation). Color uses read-only lookups only.
- **One sanctioned show write: icon `Import()` (user-approved 2026-09-26).**
  Each icon is imported at most once per show into a collection whose
  `GetChildClass()` is `SymbolImage`, named `TicTacToe_bulb` /
  `TicTacToe_speaker`, and found by name on every later activation. It only
  runs if the `.png` exists. A missing `.png.xml` sidecar is written once,
  byte-identical to MA's own (see step 11). A failed import removes its slot. Don't widen this exception. Everything else stays read-only.
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

**Secondary source (2026-07-17, user-provided):** a third-party API
reference, github.com/MacTirney/GrandMA3-API-Documentation, covers the
"Object API" and "Object Free API" with worked examples (not just
signatures). Two leads from it are now wired into the code, untested on
console as of this writing:
- `Children(handle)` (colon or bare) returns a real Lua table of child
  handles — has an actual working example (`mySequence:Children()`,
  iterated via `#`/`[i]`), unlike `GetUIChildrenCount`/`GetUIChild` which
  have never had a confirmed example. Now tried as the primary tier in
  `try_get_ui_children_count`/`try_get_ui_child`, old tier kept as
  fallback.
- Pool sub-collections may be indexed with plain brackets —
  `DataPool().Sequences[1]` — not just `:Ptr(index)`. Now tried first in
  `resolve_icon_via_pool`, `:Ptr()` kept as fallback per root candidate.
- Also notable but **not wired in**: `Dump(handle)` prints an object's
  full name/class/properties/children to the Command Line History window
  (not System Monitor). Worth suggesting to the user as a manual
  diagnostic they can run directly in the console's Lua Input popup —
  much faster than another round-trip through diag()/screenshot — rather
  than adding it to the shipped plugin (would spam Command Line History on
  every activation).
- This reference did **not** cover UI dialog construction, the plugin
  entry signature, or `Texture`/`BackColor`/`Delete` specifically — it did
  not resolve the open bugs outright, only supplied two new candidate
  mechanisms.

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

## Open bug 1 — RESOLVED: Restart doesn't clear the win line

**Symptom (historical):** after a win, hitting Restart redrew a fresh board
but the old win-line stroke blocks stayed visible on screen.

**Resolution confirmed on-console 2026-07-17, no errors.** Root cause was
step 6 below (`Children()` as the primary tier). One loose end remains,
noted after the attempt list.

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
5. `GetUIChildrenCount`/`GetUIChild` got the same dual-attempt treatment as
   `Delete` (bare-global first, then colon-method), via new
   `try_get_ui_children_count`/`try_get_ui_child` helpers, with `diag()`
   logging at every failure point on every call site — tested on console,
   **still broken**, no decisive error surfaced.
6. A third-party API reference the user linked
   (github.com/MacTirney/GrandMA3-API-Documentation, 2026-07-17) documents
   `Children(handle)` with an actual working example returning a real Lua
   table — stronger evidence than `GetUIChildrenCount`/`GetUIChild`, which
   never had one. Wired in as the primary tier ahead of the old
   dual-attempt (kept as fallback) in both helpers — **this is what fixed
   it**, confirmed on-console: line disappears on Restart, no errors.
7. The same System Monitor capture that confirmed the fix also proved
   something else definitively: `Delete(parent, 3) errored: attempt to
   call a nil value (global 'Delete')` — the bare-global form of `Delete`
   **does not exist on this build at all**. Not a naming guess gone wrong;
   a confirmed nil global. Removed that dead branch from `try_delete`
   entirely; only `parent:Delete(index)` (colon form) is called now, which
   is what was actually doing the work all along once it was correctly
   *reached* (steps 4–6 were about reaching it, not about which `Delete`
   form works).

**Loose end (not chased further, low priority):** that same capture showed
one `try_delete` call for a specific block (index 3) where the colon
`Delete` call left the count unchanged — i.e. even the working form failed
for at least one block in that pass, while the user's overall report was
positive ("line disappears... no errors"). Possibly an edge case with the
very last remaining block in a cleanup pass, or a stale/mixed capture from
Command Line History scrollback. Worth a closer look only if the user
starts seeing a *partial* residual line (a stub of 1-2 blocks) rather than
the line fully clearing.

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
6. The built-in symbols already **exist** as pool objects (`fixture1_png`
   at pool index 38, `user_png` at index 41 — visible directly in the pool
   editor screenshots). `resolve_icon` navigated to them via
   `Root().Symbols:Ptr(38)` / `:Ptr(41)` — the exact same proven mechanism
   working for the win-line color — trying 5 candidate root paths
   (`Root().Symbols`, `Root().DataPools.Symbols`, `Root().ShowData.Symbols`,
   `DataPool().Symbols`, `CurrentDataPool().Symbols`). **Untested on
   console as of the commit that shipped it** — superseded by step 7
   before a console test happened.
7. The same third-party reference that surfaced `Children()` also has a
   working example, `DataPool().Sequences[1]`, indexing a pool
   sub-collection with plain **brackets** rather than `:Ptr()`.
   `resolve_icon_via_pool` tried `root[index]` first, `root:Ptr(index)`
   second, per each of the same 5 candidate root paths from step 6 —
   **tested on console, still missed both.** System Monitor showed
   `resolve_icon(bulb): neither bracket-index nor :Ptr() found index 38
   via any candidate root path` (and the same for speaker/41) — a clean
   miss, no errors, meaning the pool objects exist somewhere but none of
   the 5 root paths × 2 indexing forms = 10 combinations tried actually
   reaches them.
8. **Current approach (untested on console):** the user then manually
   selected the exact bulb/speaker images in the console's own Symbols
   pool window and captured the command-line response:
   `Not implemented: Call Image 2.38` / `Not implemented: Call Image
   2.41`. This revealed the console's real native address for these
   objects is **`page.index`** (`"2.38"`, `"2.41"`), not the flat index
   this code had tried exclusively. Important nuance: `Not implemented`
   was the response to that specific CLI click-driven action, not to
   anything the plugin does — it says the "Call Image" command verb isn't
   implemented on this build, not that Lua handle access with the page
   included would fail too. Three page-qualified forms now tried per
   candidate root, after the existing flat forms:
   `root[page][index]`, `root[page]:Ptr(index)`, `root:Ptr(page, index)`
   (`SYMBOL_POOL_PAGE = 2`).

9. **Current approach (2026-09-26, untested on console).** The user changed
   the requirement: use the files on disk, and fall back to `L`/`S` if
   they're absent. They also approved a one-time `Import()`. Their two named
   screenshots (`gma3_library/media/images/20260716_212046_display1.png` =
   bulb, `..._212026_...` = note) turned out to be full 3840x2054 captures of
   the Import browser, not icons. With the user's agreement, the plugin uses
   the stock files those screenshots show:
   `gma3_<Version() X.Y.Z>/shared/resource/lib_symbols/object/fixture1.png`
   and `.../executor/executor_learnspeed.png`. Each has a `.png.xml` sidecar
   (`<SymbolImage FileName=... FilePath=.../>`), and that sidecar is what
   `obj:Import(dir, "<file>.png.xml")` loads. The pool is found at
   `ShowData().MediaPools.Symbols` first. The "Image 2.38" address reads as
   media pool 2 (Symbols), item 38, which suggests step 8's "page" theory was
   wrong. Restart restores each played cell's build-time `Texture`, because
   working icons would otherwise persist.
   Known risk: `gma3_2.3.2` has the pngs but **no** `.png.xml` sidecars, so a
   2.3.2 console gets letters only.

10. **On-console result of step 9 (2026-09-26):** the import **worked**. The log
   showed `icons: imported fixture1.png.xml as TicTacToe_bulb` (and the same
   for the speaker), and Symbols pool slots 44/45 held the right images. The
   second activation reused them without re-importing. But every cell given
   `Texture = <SymbolImage>` lost its grey background and drew no image. MA's
   own `lib_menus` Lua explains why: `Texture` is a widget's **background
   frame** (`"corner1"`, `TextureCollect.Textures["frame15"]`), `Icon` takes
   internal UI texture names (`"triangle_left"`), and a **pool image is shown
   via `AppearancePreview.Appearance = <image object>`** (`image_editor.lua`).
   The fix is a lazily created `AppearancePreview` over each occupied cell,
   hidden and shrunk to 0x0 on clear. It is untested on-console. **Never write
   `Texture` for icons again.** That same background-frame meaning is also
   the real cause of the 2026-07-17 black-grid bug (`Texture = ""`).
   **Lesson: grep `gma3_<ver>/shared/resource/lib_menus` (MA's own shipped UI
   Lua + uixml) before guessing any UI property. It's local ground truth and
   more useful than the HelpLua dump for UI questions.**

11. **Second PC (2026-09-27): "(or its .xml) not found".** The pngs were
   there, but the `.png.xml` sidecars were not. **MA3 does not ship
   sidecars.** On the dev PC they're dated 2026-07-17 00:17, while the pngs
   are dated with the install. The Import Image dialog
   (`lib_menus/ui/editors/image_import.lua`) runs
   `Cmd("Import Image ... /File <png> /Path <dir>")` on the bare png, and MA
   writes the sidecar as a cache the first time. Our `obj:Import(dir, xml)`
   skips that step. Fix (user-approved): when the png exists and the sidecar
   doesn't, write it once with `io.open`, using MA's exact bytes (UTF-8 BOM,
   `<GMA3 DataVersion="<Version()>">`, a 4-space-indented `<SymbolImage
   FileName=.. FilePath=<subdir>/>`, LF endings). All 4 generated files were
   verified byte-identical to the real ones on the dev PC. Untested on the
   second PC. **Lesson: a file that exists on the dev machine might be one
   that the dev's own clicking created. Check file dates against the
   install date before assuming it's stock.**

**Next step if step 10 still does not show icons** (older note, still applies): this is now 8 distinct approaches
across 3 rounds, all misses, with the flat-index forms proven wrong by two
separate lines of evidence (10 silent misses, plus the console's own
`2.38` addressing). If the page-qualified forms ALSO miss, that points at
the *root path* itself being wrong rather than the indexing syntax — at
that point, stop guessing root paths and have the user run
`Root():Dump()` (or similarly `Root().Symbols:Dump()` if that resolves at
all) directly in the console's Lua Input popup (see `Dump()` under "Ground
truth source" above). That prints the actual property names to Command
Line History and ends the guessing entirely, likely faster than another
round of screenshots. The user was asked directly (2026-07-17) whether to
keep pursuing icons or accept letters as final, and chose one more
attempt (this one) — worth asking again if this round also misses, since
letters already work and are fully legible.

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
- Classic (unrigged) sibling, added 2026-09-26: `plugin/TicTacToeClassic.lua`,
  `.xml` and `test_classic_ui.lua`. It was derived from the working rigged
  build: SECTION 1 is swapped for classic rules (X first, either player wins,
  draw), and it uses X/O letters with the `lib_symbols/symbols/x_mark_black`
  and `outline_circle_black` icons. It has its own `Ttc*` callbacks, dialog
  name, `[TicTacToeClassic]` log prefix and `TicTacToeClassic_x/_o` pool
  entries. **The two files share UI and icon code by copy, not by module.**
  A fix to the shared parts (SECTIONS 3-11) usually needs applying to both.
- Test harnesses: `plugin/test_logic.lua`, `plugin/test_ui_geometry.lua`
- Packaging: `plugin/TicTacToe.xml`, `docs/INSTALL.md`
- Ground truth API reference (user's machine, not in this repo):
  `C:/ProgramData/MALightingTechnology/gma3_library/grandMA3_lua_functions.txt`
- `CHANGELOG.md` has a detailed `[Unreleased]` entry per bugfix round —
  more granular blow-by-blow than this file, worth reading if this
  document doesn't answer a specific question.
