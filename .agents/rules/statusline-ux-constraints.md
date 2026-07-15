# Version 1.1.1

# Statusline UX Constraints

Always-on conventions for any agent environment statusline renderer. Apply
whenever adding or modifying a ticker - Claude, Antigravity, or any future
provider. Implementation paths differ per provider; the UX laws do not.

> **Claude implementation:** `dotfiles/.claude/statusline.py`
> **Antigravity implementation:** `dotfiles/.antigravity/statusline.py`

---

## 1. Fixed-width tickers (no wiggle rule)

Every ticker that displays dynamic data must have **a fixed visible width**.
The statusline is a static footer. Layout shifts from variable-length content
are distracting and visually noisy.

### Rules

- **Label fields**: pad to the max possible label width with `str.ljust(N)`.
  Example: effort level names max out at `medium` (6 chars) -- pad all levels
  to 6 so `low` never shifts the slider rightward.

- **Time fields**: always use zero-padded two-digit minutes.
  `Mm SSs` format: `f"{mins:02d}m{secs:02d}s"` -> `00m00s` ... `59m59s` (6 chars, fixed).
  `Xh MMm` format: `f"{hrs}h{mins:02d}m"` -> acceptable variable (hours rarely hit 10+).

- **Percentage fields**: use `:6.2f` format spec -> always 6 chars before `%`
  (`  0.00`, ` 30.00`, `100.00`). The leading spaces are inside the bracket
  and invisible in practice but guarantee width stability.

- **Bar fields** (progress bars): fixed bar length (e.g. 12 chars). Never vary
  the bar length based on data. `int(pct * 12 / 100)` filled + remainder empty.

### What NOT to do

```python
# Bad: "30.00%" jumps to "100.00%" at full capacity (7 chars)
f"{pct:.2f}%"

# Bad: "5m00s" jumps to "10m00s" at 10 minutes
f"{mins}m{secs:02d}s"

# Bad: "low" (3) vs "medium" (6) shifts slider by 3 chars
f"[effort:{level} {slider}]"

# Good: fixed-width equivalents
f"{pct:6.2f}%"
f"{mins:02d}m{secs:02d}s"
f"[effort:{level.ljust(6)} {slider}]"
```

---

## 2. Line alignment

Lines 2 and 3 must have the same visible width (enforced by the L2/L3 padding
block in `statusline.py`). When adding tickers to either line, verify the
alignment test `test_lines_2_and_3_same_visible_width` still passes.

---

## 3. Model-aware effort slider

The effort slider is model-specific and provider-specific. Each provider
maintains its own `MODEL_EFFORT_LEVELS` mapping. When a provider adds a new
model or effort level, update that provider's renderer and its slider width.

**Claude (Anthropic) model -> level mapping (June 2026):**
- `haiku`: no effort support -> dim static rail (`────────`)
- `sonnet`: `low medium high max` (4 levels, 8-char slider)
- `opus`, `fable`: `low medium high xhigh max` (5 levels, 10-char slider)

**Antigravity (Gemini) model -> level mapping:** maintained in
`dotfiles/.antigravity/statusline.py` by its own provider.

---

## 4. Inference cost

The statusline runs on every keypress while Claude Code is active. Keep the
render function fast and allocation-light. Avoid disk I/O inside tight loops;
all file reads (sidecar JSON) use `contextlib.suppress(Exception)` guards so
a missing/corrupt file never stalls the render.

The statusline has a hard budget of < 0.1% of monthly inference cost. No
new API calls, no subprocess spawns, no network I/O inside `statusline.py`.
