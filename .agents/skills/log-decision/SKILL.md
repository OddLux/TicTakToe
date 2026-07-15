---
name: log-decision
description: >
  Two-tier decision logger. Routes to DECISIONS.md (product-facing, root),
  decision-ledger.md (agent-facing, .agents/knowledge/), or both. Includes
  grill mode for HIGH-significance decisions. Invoked explicitly or triggered
  automatically by the commit-changes skill after feature commits.
version: 2.2.0
status: stable
runs: 0
last-run: never
upgrade-conditions:
  - "DECISIONS.md format changes"
  - "decision-ledger.md format changes"
  - "routing logic changes"
  - "grill questions revised"
---

# Log Decision

Records design decisions into one or both tiers of the project decision ledger.
Prevents future re-exploration of dead ends and preserves institutional memory
for both human collaborators and future agent sessions.

## Two-tier system

| Tier | File | Audience | Voice |
|------|------|----------|-------|
| Product | `DECISIONS.md` (project root) | Collaborators, future maintainers, anyone who clones the repo | Strictly harness-agnostic product and architectural language. Written as if the agentic harness never existed. No mentions of agents, models, rules, or skills. Reads like an ADR. |
| Agent | `.agents/knowledge/decision-ledger.md` | Agent itself, cold-start context reconstruction | Terse. Can reference skill names, rule files, agent-internal concepts freely. Includes harness/infra design decisions. |

## Flags

- `--product` -- route to `DECISIONS.md` only, skip routing question
- `--infra` -- route to `decision-ledger.md` only, skip routing question
- `--quick` -- skip grill mode even if significance is HIGH
- `--grill` -- force grill mode regardless of significance score

## When to invoke

- User says "log this", "record why we did this", "add a decision entry"
- Automatically triggered by `commit-changes` after a `feature` commit
- When a studio ticket (PTSUP-xxxx, JIRA-style) is being processed and
  decisions or constraints are surfaced in the discussion
- When release notes are being generated and un-logged decisions are identified
  since the last release tag

---

## Instructions

### Phase 0: Determine flags

Check the invocation for `--product`, `--infra`, `--quick`, `--grill`.
If invoked from `commit-changes`, the commit type is `feature` -- treat as
significance HIGH unless commit touches only 1 file.

### Phase 1: Gather decision context

Extract from the current conversation:

- **Title** -- short plain-English summary (<= 8 words)
- **Decision** -- what was chosen and the primary reason
- **Why** -- bullet reasons, constraints, data points that drove the choice
- **Rejected** -- what was not chosen, and why it was dismissed
- **Future** -- optional: conditions under which this decision should be revisited

If any field is unclear, ask before writing.

### Phase 2: Score significance

Apply the heuristic table below. Significance is HIGH/MEDIUM/LOW.

| Signal | Significance |
|--------|-------------|
| Commit type is `feature` | HIGH |
| Commit touches >3 files across >1 system boundary | HIGH |
| Release notes being generated (un-logged decisions pass) | HIGH |
| Studio ticket distillation (PTSUP-xxxx, meeting notes) | HIGH |
| Commit type is `refactor` on a core module | MEDIUM |
| A previously open option is being closed ("we're going with X") | MEDIUM |
| External dependency being added or dropped | MEDIUM |
| Commit type is `chore`, `docs`, `style`, `test` | LOW |
| Trivial single-file edit (typo, comment) | LOW |
| Read-only task | LOW |

### Phase 3: Grill mode

**When to grill:**
- Significance is HIGH AND `--quick` was not passed -> grill
- `--grill` flag present -> grill regardless of score
- Significance MEDIUM or LOW, no `--grill` flag -> skip grill

**Grill sequence (ask in order, stop early if answers already present):**

**Q1:** "What is the strongest argument against this decision?"
Forces surfacing the rejected path's best case. If the user's answer to
Q1 already implies the reversal condition, skip Q2.

**Q2:** "What would have to be true for you to reverse this in V2?"
Forces articulation of the reversal condition -- the most valuable field
in any decision log.

**Q3 (optional, context-dependent):** "Did you consider [X]?"
Suggest plausible alternatives based on the decision domain only if no
alternatives have been named yet. Do not invent specifics -- ask open-endedly.

Grill answers feed directly into **Rejected** and **Future** fields.
Do not ask all three mechanically if the answers are already in the conversation.

### Phase 4: Route the entry

If `--product` or `--infra` was passed, skip the routing question.
Otherwise, route based on the nature of the decision:
- High-level design choices for the tool/application itself (tech stack, UX structure, architecture boundaries, external API integrations) -> `DECISIONS.md`
- Harness configuration, agent behavior, rules, skills, scripting, or local repo tooling -> `decision-ledger.md`

| Decision type | `DECISIONS.md` | `decision-ledger.md` |
|---------------|:--------------:|:--------------------:|
| Product / application architecture | YES | optional (if agent-relevant) |
| Harness / agent config / internal protocol | NO | YES |
| Studio ticket (product-facing aspect) | YES | YES |
| Studio ticket (infra-only aspect) | NO | YES |
| `--product` flag | YES | NO |
| `--infra` flag | NO | YES |

### Phase 5: Write entries

#### Deduplication contract

An entry must NEVER repeat information already in the associated commit message.
- Git commit message = what changed + one-line why (100 chars max)
- `decision-ledger.md` = full why, alternatives, reversal condition -- not what changed
- `DECISIONS.md` = same substance as ledger, product language -- not commit diff details
- `CHANGELOG.md` = user-facing impact -- not implementation decisions

An agent should reconstruct full context by reading commit + entry together,
without either being redundant.

#### DECISIONS.md entry format (product voice)

Full sentences. Strictly harness-agnostic language. Write as if the agentic harness or any AI coding assistant never existed.
- **Never** mention AI models (e.g. Gemini, Sonnet, Opus), agents (e.g. ticket-bouncer), or harness concepts (e.g. `.agents/`, `.claude/`, rule files, skills, slash commands).
- Focus purely on the architectural design and product vision.

```markdown
## YYYY-MM-DD -- Short decision title

[caveman][level]: 1-2-3 liner decision and why
```

Newest-first. One `---` separator between entries. No frontmatter.

#### decision-ledger.md entry format (agent voice)

Terse. May reference skill names, rule files, agent IDs, ticket numbers.

```markdown
## [YYYY-MM-DD] Title

[caveman][level]: 1-2-3 liner decision and why

**Context:** ...

**Decision:** ...

**Alternatives rejected:**
- *Option A* - reason dismissed
- *Option B* - reason dismissed

**Reversal condition:** ...

**Outcome:** Pending | Validated | Superseded
```

### Phase 6: Create files if missing

**If routing to `DECISIONS.md` and the file does not exist:**
Create it with this header (no frontmatter, no extra sections):

```markdown
# Decision Log

Newest first. Each entry: decision, why, what was rejected and why.

---
```

Then prepend the new entry immediately after the `---`.

**If routing to `decision-ledger.md` and the file does not exist:**
Create it with this header:

```markdown
# Decision Ledger

Running record of design decisions, rejected approaches, and deliberate
tradeoffs. Entries are newest-first. Each entry explains WHY - preventing
re-exploration of dead ends and preserving institutional memory.

---
```

Then prepend the new entry immediately after the `---`.

### Phase 7: Prepend entries

Insert the new entry immediately after the opening `---` separator (newest-first).
Do not modify existing entries.

### Phase 8: Do not commit automatically

Stage the modified file(s) alongside whatever work prompted the log entry.
The `commit-changes` skill handles the commit.

---

## Studio ticket distillation mode

When a PTSUP-xxxx, JIRA-style ticket, or meeting notes are being processed:

1. Identify any explicit decisions or constraints surfaced in the discussion.
2. Offer to distill them: "I see a decision here -- log it? (`/log-decision` or `skip`)"
3. Route: product decisions -> `DECISIONS.md`; infra/agent decisions -> ledger; both if significant.

This is the highest-priority trigger. Do not wait for explicit invocation.
