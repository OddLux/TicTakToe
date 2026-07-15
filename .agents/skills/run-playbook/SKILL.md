---
name: run-playbook
description: >
  Interactive playbook selector and questionnaire runner. Lists all playbooks,
  lets the user pick one, then walks through it step by step - verifying what
  it can, asking the user for what it cannot. Use when invoked via /playbook,
  or when the user says "run a playbook", "walk me through a playbook", or
  "set up X" and a relevant playbook exists.
version: 1.0.0
status: experimental
runs: 0
last-run: never
upgrade-conditions:
  - "playbook frontmatter schema changes"
  - "new playbook status values added"
---

# Run Playbook (Interactive Questionnaire)

**Mission:** A playbook is a wiki page ready for both human and agent to work
through a workflow together. This skill is its execution engine.

---

## Phase 1: Discovery

Scan `.agents/playbooks/` for all `*.md` files. For each, read the YAML
frontmatter (slug, status, scope, maturity, upgrade-conditions). Build a
registry in memory:

```
slug | status | maturity | scope | upgrade-conditions[]
```

Do this silently before saying anything.

---

## Phase 2: Selection Menu

Print a numbered list grouped by `scope`, sorted: mature first, then evolving,
then prototype. Deprecated playbooks are listed last under a "-- deprecated --"
separator. Show status emoji inline:

| Status | Emoji |
|--------|-------|
| stable | ✅ |
| verified | ✔ |
| ready | 🟡 |
| draft | 🔴 |
| deprecated | ⚠ |

Example output:

```
Available playbooks:

  git
  1. ✔  git-hooks-setup       [evolving]
  
  setup
  2. ✔  vscode-extensions-setup [mature]
  3. 🟡 opencode-setup-guide    [prototype]
  
  ingestion
  4. ✔  prototype-absorption    [evolving]
  
  ops
  5. 🔴 multi-agent-orchestration [prototype]
  6. ✔  git-worktree-management   [evolving]

  -- deprecated --
  (none)

Pick a number, or type the slug name:
```

Wait for user input. If they type a name that does not match, ask again.

---

## Phase 3: Pre-run Check

Before starting, check `upgrade-conditions` for the selected playbook. If any
condition may have been triggered since `last-verified`, surface a one-line
warning:

> ⚠ This playbook was last verified YYYY-MM-DD. Conditions that may make it
> stale: [condition list]. Proceed anyway? (y/n)

If no upgrade conditions are flagged, or user confirms: proceed.

If playbook is `draft`: warn "Steps incomplete. Treat as a rough guide, not a
verified procedure. Proceed? (y/n)"

---

## Phase 4: Execution Loop

Read the selected playbook. Walk through it section by section.

### Step detection

Detect two step formats:

**Format A - Explicit step (dp-011 format):**
```
## Step N: <title>
**Verify:** `<command>`   <- agent runs this
**Fail fix:** <instruction>
```
or
```
## Step N: <title>
**Action:** <what user must do>
**Fail fix:** <instruction or URL>
```

**Format B - Reference section (current playbooks):**
Any `##` heading that is not a Step N header. Treat the whole section as a
single user-action block.

### Per-step loop

For **Verify** steps:
1. Print: `[Step N] <title>`
2. Run the verify command. Show trimmed output (first 5 lines).
3. If exit code 0: print `✔ pass` and advance.
4. If non-zero: print `✘ fail`. Show fail-fix instruction. Ask "Fixed? Re-check (y) or skip (s)?"
   - `y`: re-run verify. Loop until pass or user skips.
   - `s`: mark step skipped, continue.

For **Action** steps (or reference sections):
1. Print the step title and content (max 30 lines; if longer, print first 20
   then "... [N more lines - type 'more' to expand]").
2. Ask: `Done? (y / n / more / skip)`
   - `y`: advance.
   - `n`: ask "What's blocking you?" - give a one-sentence hint if context
     available, then re-ask.
   - `more`: print remaining lines, then re-ask.
   - `skip`: mark skipped, continue.

### Progress indicator

Print a compact header before each step:
```
── Step 2 / 5 ─────────────────────────────
```

---

## Phase 5: Done State

When all steps are complete (or skipped):

1. Print the playbook's done-state if defined (look for a `## Done State` or
   `**Done state:**` line in the playbook). If none, print "All steps covered."

2. Show step summary:
   ```
   ✔ 4 passed  |  ⊘ 1 skipped  |  ✘ 0 failed
   ```

3. Ask: "Mark this run as successful? (y/n)"
   - `y`: update the playbook frontmatter:
     - Increment `usage-count` by 1
     - Set `last-verified` to today's date (YYYY-MM-DD)
     - If `verified: false`, set to `true` and bump `status` to `verified`
     - Recalculate `success-rate` as `round(100 * passes / total_runs)`
   - `n`: leave frontmatter unchanged.

4. Ask: "Anything to improve in this playbook? (y/n)"
   - `y`: ask what. Append a brief note to the playbook under an
     `## Improvement Notes` section (create if absent). Each note: `- YYYY-MM-DD: <note>`

---

## Upgrade Condition Check (Always On)

When the agent detects any of the following during a session, flag to the user
that relevant playbooks may need review:

- A skill, command, or agent is added or modified that overlaps a playbook's scope
- `AGENTS.md` playbook schema changes
- A tool used in a playbook's verify commands appears missing or version-mismatched
- User reports a playbook step failed

Say: "Playbook `<slug>` may need review - its upgrade-conditions include
`<condition>`. Consider re-running `/playbook` to verify it still holds."

---

## Notes

- This skill does not modify playbook content beyond frontmatter metadata and
  improvement notes.
- If no playbooks exist, print: "No playbooks found in `.agents/playbooks/`.
  Create one using the PLAYBOOK_TEMPLATE.md format."
- Session state is in-conversation only. If the session restarts mid-playbook,
  ask "Which step did you reach?" and resume from there.
