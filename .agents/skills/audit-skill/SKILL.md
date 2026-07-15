---
name: audit-skill
description: >
  Validates new or modified skills and protocol changes against the existing
  dev protocol. Checks for duplication, workflow conflicts, convention
  compliance, and estimates inference cost impact. Auto-triggers whenever a
  skill file is created or modified, or when AGENTS.md / CLAUDE.md changes.
  Trigger: new .agents/skills/*/SKILL.md created, existing skill modified,
  AGENTS.md changed, CLAUDE.md changed.
version: 1.0.0
status: experimental
runs: 0
last-run: never
upgrade-conditions:
  - "AGENTS.md skill/rule conventions change"
  - "new protocol layers added"
---

# Skill Audit

Run this every time a skill is added or a protocol file changes. Goal: keep
the protocol cohesive, non-redundant, and inference-efficient. Be permissive
early; get stricter as the protocol matures.

---

## Trigger conditions

Auto-run when any of these files change:

- `.agents/skills/*/SKILL.md` (new or modified)
- `AGENTS.md`
- `CLAUDE.md`
- `.agents/rules/*.md`

---

## Audit checklist

Work through each dimension in order. One short finding per item - blank if
clean.

### 1. Duplication

Scan all existing skill names, descriptions, and trigger lines in
`.agents/skills/*/SKILL.md` and the skills table in `AGENTS.md`.

- Does any existing skill already cover this purpose fully or substantially?
- Do trigger phrases overlap with another skill's triggers?
- Would merging this into an existing skill be cleaner?

### 2. Workflow conflicts

Read `AGENTS.md` (Workflow Triggers section) and all always-on rules in
`.agents/rules/`.

- Does this skill fire on the same trigger as another skill, causing a
  collision?
- Does it contradict a rule (e.g., recommends something a rule forbids)?
- Does it depend on a skill/command that doesn't exist yet?

### 3. Convention compliance

Check the skill file itself against AGENTS.md conventions:

- Has YAML frontmatter with `name` and `description`?
- `description` lists at least one `Trigger:` line?
- No hardcoded paths that will break outside this repo?
- No commit instructions (that's `commit-changes`'s job)?
- No version-bump instructions (that's `derive-version`'s job)?

### 4. Inference cost estimate

Estimate the cost impact using the rubric below. A skill that fires every
session is expensive; one that fires on a rare explicit command is cheap.

**Load frequency** (how often does this skill's content enter context?):

| Frequency | Score |
|-----------|-------|
| Always-on (loaded every session via rules/) | HIGH |
| Workflow-triggered (fires on common task endings) | MEDIUM |
| Command-triggered (explicit /command only) | LOW |
| Manual-only (user must invoke it by name) | MINIMAL |

**Token weight** (rough size of the SKILL.md itself):

| Size | Score |
|------|-------|
| > 150 lines | HEAVY |
| 50-150 lines | MEDIUM |
| < 50 lines | LIGHT |

**Cascade factor** (does it spawn subagents or chain skills?):

| Behavior | Score |
|----------|-------|
| Spawns 2+ subagents | +HIGH |
| Spawns 1 subagent or chains 1 skill | +MEDIUM |
| No spawning | +NONE |

**Composite inference cost** = Load frequency + Token weight + Cascade factor.
Express as: `LOW / MEDIUM / HIGH / CRITICAL`.

### 5. Human attention cost

How much human attention does invoking this skill require?

- Does it require the user to answer questions or make decisions? (`MEDIUM`+)
- Does it produce output the user must read and act on? (`MEDIUM`)
- Does it run silently and self-complete? (`LOW`)

Express as: `LOW / MEDIUM / HIGH`.

---

## Output format

Print this block after completing the checklist:

```
SKILL AUDIT: <skill-name>
  duplication      › <"none" | "overlaps with X: <detail>">
  conflicts        › <"none" | "<what conflicts with what>">
  compliance       › <"pass" | "missing: <field>">
  inference cost   › <LOW|MEDIUM|HIGH|CRITICAL> (<load-freq> load, <weight> file, <cascade> cascade)
  human attention  › <LOW|MEDIUM|HIGH>
  verdict          › <APPROVE | REVIEW | REJECT>
  notes            › <optional 1-2 sentence free-form note>
```

**Verdict rules:**

| Verdict | Condition |
|---------|-----------|
| `APPROVE` | All clean. Safe to ship. |
| `REVIEW` | One or more soft concerns (partial overlap, HIGH cost, attention drain). Flag for user decision. |
| `REJECT` | Hard conflict: duplicate of existing skill, breaks a rule, missing required frontmatter. Must be resolved before merging. |

---

## Escalation to convention-sentinel

For simple single-skill additions, run the checklist inline (above).

Escalate to `convention-sentinel` when:
- A new agent definition is added
- A `.agents/rules/*.md` file is created or modified
- `AGENTS.md` workflow triggers section changes
- A skill is renamed or removed
- More than one protocol artifact changes in the same commit

🪨 CAVECREW
   agent    › convention-sentinel
   mission  › deep convention audit - compliance + cost + conflict scan

Sentinel returns `APPROVE / REVIEW / REJECT`. Use that verdict as the
final verdict for this audit run.

---

## After the audit

- `APPROVE`: proceed. Run `commit-changes` as normal.
- `REVIEW`: present findings to user. Wait for their call before committing.
- `REJECT`: block commit. State what must change. Do not proceed.

For `REVIEW` or `REJECT`, suggest concrete fixes - rename, merge target,
missing field to add, cost reduction approach.
