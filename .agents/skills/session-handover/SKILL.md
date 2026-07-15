---
name: session-handover
description: >
  Captures session retrospective and deploys a session package to
  .agents/sessions/. Two tiers: crumbs (skinny, default) and loaf (full fat,
  --loaf flag). crumbs = goal + shipped + loose ends + hot context + budget.
  loaf = full retro + agent log + telemetry + plan refs. Also writes the
  legacy retro-<date>-<slug>.md to .agents/knowledge/ for backwards compat.
  Trigger: "postmortem", "debrief", "session handover", "save retro",
  "what happened this session", "/session-handover", "/session-handover --loaf".
invocation: agent
version: 2.0.0
status: experimental
runs: 0
last-run: never
upgrade-conditions:
  - "session-cost.json schema changes"
  - "retro file naming conventions change"
  - "new retro sections required"
  - "manifest.toml schema changes"
---

# session-handover

Deploys a session package to `.agents/sessions/` and writes a legacy retro
file to `.agents/knowledge/`. Two package types: **crumbs** (default) and
**loaf** (full fat, requires `--loaf` flag).

---

## Package Types

### crumbs (default)

Skinny handover. ~20 lines. Fast to write, fast for the next session to read.
Contains: goal, shipped artifacts, loose ends, hot context, budget estimate.

### loaf (--loaf flag)

Full fat handover. Contains everything in crumbs plus: full retro narrative
(attempted/shipped/rejected/surprises/loose ends/process notes), agent log
summary, inference telemetry, decision references, plan file pointers.

---

## When to use

- Session is ending or handing off to a new session
- A significant approach was tried and rejected
- Multiple agents were spawned (coordination pattern worth preserving)
- A protocol-guardian REJECT caught something
- User says "postmortem", "debrief", "save retro", "/session-handover"
- Any time: a crumbs handover costs ~2 minutes and pays off every next session

---

## Step 0: Determine package type

- No flag or `--crumbs` -> generate crumbs only
- `--loaf` -> generate crumbs + loaf (crumbs is always generated)

---

## Step 1: Generate 3-word slug

Derive a 3-word slug for this session package:
1. Take the first 2 significant words from the active goal (from the active provider's `goal-state.json`)
   or from the session's primary topic if no goal is set.
2. Append a 3rd word: short noun or hex from current timestamp mod 4096.
3. Kebab-case, lowercase.

Examples:
- Goal "upgrade handover skill" -> `upgrade-handover-v2`
- Goal "fix statusline drift" -> `fix-statusline-loop`
- No goal -> `session-<date-hhmmss>`

---

## Step 2: Create package directory

```
.agents/sessions/YYYY-MM-DD_<3-word>/
  manifest.toml
  crumbs.md
  loaf.md           (--loaf only)
  plans/            (copied from active session plans if any exist in the active provider's config `tmp/` directory)
```

Create the directory. If it already exists (rare: same-day double handover), append `-b` suffix.

---

## Step 3: Read budget data

Attempt to read `session-cost.json` from the active provider's configuration directory. If absent or unreadable, use
`null` for all budget fields. Do not fail on missing budget data.

```json
// expected shape (from session_cost.py)
{
  "session_id": "...",
  "total_tokens": 12345,
  "estimated_cost_usd": 0.045,
  "input_tokens": 10000,
  "output_tokens": 2345
}
```

---

## Step 4: Write manifest.toml

```toml
[session]
date = "YYYY-MM-DD"
slug = "word-word-word"
type = "crumbs"   # or "loaf"
goal = "<goal title from goal-state.json, or empty>"
model = "<model id from payload or env>"

[budget]
source = "<active-provider-config-dir>/session-cost.json"
tokens_total = <int | null>
tokens_input = <int | null>
tokens_output = <int | null>
cost_usd = <float | null>

[artifacts]
retro = "retro-YYYY-MM-DD-<slug>.md"   # path relative to .agents/knowledge/
commits = []   # list of commit hashes from this session (from git log --since)
tickets = []   # dp-NNN list touched/opened/closed this session
plans = []     # list of plan-<3-word>.md filenames if plans/ subdir populated
```

To populate `commits`: run `git log --since="YYYY-MM-DD 00:00" --format="%h %s"` and include hashes from today.
To populate `tickets`: scan conversation for dp-NNN references.

---

## Step 5: Write crumbs.md

```markdown
# Handover Crumbs: <goal or session topic>
Date: YYYY-MM-DD | Model: <model> | Budget: ~$X.XX (~N tokens) | Type: crumbs

## Goal
<one-line imperative goal, or "no goal set">

## Shipped
- <commit hash> <subject line>
- dp-NNN: <ticket title> [closed|opened|updated]

## Loose Ends
- <unresolved item or fragile assumption>

## Hot Context
<2-3 lines: current state, immediate next action for the next session>
```

---

## Step 6: Write loaf.md (--loaf only)

Loaf contains everything in crumbs plus the full six-section retro:

```markdown
# Handover Loaf: <goal or session topic>
Date: YYYY-MM-DD | Model: <model> | Budget: ~$X.XX (~N tokens) | Type: loaf

## Goal
<one-line>

## Shipped
<bullet list with commit hashes and ticket IDs>

## Attempted
<bullet list: what was tried this session>

## Rejected
<bullet list: what was rejected, by what mechanism, why>

## Surprises
<bullet list: unexpected findings or behaviors>

## Loose Ends
<bullet list: unresolved items, fragile assumptions, next steps>

## Process Notes
<bullet list: what to repeat or avoid>

## Agent Log
<bullet list: which agents spawned, what they returned (PASS/BLOCK/KICKBACK)>

## Inference Telemetry
Input: N tokens | Output: N tokens | Total: N tokens | Est. cost: $X.XX
Source: <active-provider-config-dir>/session-cost.json

## Plan References
<list of plan-<3-word>.md files in plans/ if any>
```

---

## Step 7: Write legacy retro (backwards compat)

Write `.agents/knowledge/retro-<date>-<slug>.md` using the original format:

```markdown
# Session Retro: <topic title>
Date: YYYY-MM-DD

## Attempted
## Shipped
## Rejected
## Surprises
## Loose Ends
## Process Notes
```

For crumbs: populate only Shipped and Loose Ends (other sections empty or "N/A - crumbs only").
For loaf: populate all six sections from loaf.md content.

Do NOT update MEMORY.md. Do NOT update decision-ledger.md.

---

## Step 8: Copy plans (if any)

If plan files exist from this session in the active provider's config `tmp/` directory (placed there by
the planning-mode-sla rule), copy them to `plans/` inside the package directory.
Update `manifest.toml` `plans` array with their filenames.

---

## Step 9: Confirm to user

Print:
```
Package: .agents/sessions/YYYY-MM-DD_<slug>/
  manifest.toml  [date, model, budget]
  crumbs.md      [goal, shipped, loose ends, hot context]
  loaf.md        [full retro]          (if --loaf)
  plans/         [N plan files]        (if any)
Retro: .agents/knowledge/retro-YYYY-MM-DD-<slug>.md
```

---

## Sub-agent signal check (before writing)

Before writing any file, scan the conversation for:
- Agent KICKBACK blocks -> flag under Loose Ends if unresolved
- Agent BLOCK/REJECT/WARN -> log under Loose Ends if unresolved
- Design decisions surfaced by agents -> ask if they should go to decision-ledger
- New requirements or constraints -> capture under Loose Ends

This step prevents signal loss when multiple agents were involved.
