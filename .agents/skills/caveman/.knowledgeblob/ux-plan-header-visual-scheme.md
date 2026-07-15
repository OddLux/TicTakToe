# UX Plan Header Visual Scheme

> Source: Sonnet UX consultant 2026-06-18
> Status: approved -- apply to all plan documents

---

## The Convention

Every plan document opens with a two-part branded header card:

### Part 1: Version Stamp (colored)
```markdown
> [!NOTE]
> 🗿 **vNNN** -- one-liner: what changed in this version
```
Renders as blue callout in VS Code / Obsidian / GitHub.
Terminal: degrades to `> NOTE` blockquote -- still readable.

### Part 2: Plan Box (monospace card)
```markdown
```text
┌─ PLAN: <slug> ──────────────────────────────────────┐
│ goal    : <8-word imperative>                        │
│ scope   : <N sources> | <N tiers> | <context tag>   │
│ sequence: step1 -> step2 -> step3 -> outcome        │
│ <section>:                                          │
│   item (annotation)                                 │
│ gaps    : item1 | item2 | item3                     │
│ next    : <single next action>                      │
└─────────────────────────────────────────────────────┘
```
```
Renders with code-block background tint -- visual "card" isolation.
Monospace guaranteed across all targets. Max width: 76 chars.

---

## Brand Mark

🗿 appears ONCE per header, on the version stamp line only.
First thing the eye lands on. Functions as logo. Do not scatter.

---

## Why Two Parts

Stamp = "what version, what changed" -- narrative, colored, fast scan.
Box = "full structure" -- monospace, detailed, confirms plan shape.

Together: functions like git commit. Stamp = subject line. Box = body.
Read stamp to orient. Read box to confirm plan is sound. Skip rest if box checks out.

---

## Render Targets

| Target | Stamp | Box |
|--------|-------|-----|
| VS Code preview | blue callout | gray background card |
| Obsidian | blue/purple callout | gray background card |
| GitHub | blue callout | gray background card |
| Terminal (plain) | `> NOTE` blockquote | verbatim monospace |

## Width Constraint

Keep box total width <= 76 chars. GitHub narrow viewport triggers horizontal
scroll above ~80. 76 is safe across all targets.
