---
name: ticket-creator
description: >
  Interactive or autonomous scaffold for creating structured, subagent-ready tickets.
  Supports standard tickets and unstructured "idea tickets" (direct brain dumps to tickets).
  Determines the next dp-NNN ID, checks for duplicates/contradictions in the ledger,
  applies creep protection gates, and outputs a ticket that can be ingested directly by a subagent.
  Trigger: user says "create a ticket", "/new-ticket", "scaffold a bug ticket", or "turn this idea into a ticket".
version: 1.1.1
status: experimental
runs: 0
last-run: never
upgrade-conditions:
  - "ticket template changes"
  - "BACKLOG.md schema changes"
  - "dp-NNN ID format changes"
---


# Ticket Creator Skill

This skill scaffolds and registers a new `dp-NNN` ticket. It is designed to be executable either by a human/agent pair or autonomously by a spawned subagent. It enforces scope control (creep protection) and produces a **Subagent-Ingestible Spec** so that tickets can double as standalone prompts for worker agents.

---

## Usage Trigger

- The user says "create a ticket", "/new-ticket", "scaffold a bug ticket", or "turn this idea into a ticket".
- The agent identifies a new unit of work in `TODO.md` during a session triage.
- An issue is identified via test failures, linting errors, or user screenshots.

---

## Execution Flow

### 1. Pre-Flight Checks & De-duplication
- **Check backlog:** Scan `BACKLOG.md` (and existing files in `.tickets/open/` and `.tickets/closed/`) for keywords matching the new ticket's topic. If a matching ticket exists, append notes there instead of creating a new one.
- **Check decision ledger:** Read `.agents/knowledge/decision-ledger.md` to ensure the proposed feature or bugfix doesn't contradict past architectural decisions. If a contradiction exists, warn the user/parent and resolve it before proceeding.
- **Determine ID:** Find the highest `dp-NNN` identifier in `.tickets/open/` and `.tickets/closed/`. The new ID will be `dp-` followed by the next sequential zero-padded 3-digit number.

### 2. Creep Protection Gate
Before writing the ticket, answer these three scoping questions:
1. **What is the absolute minimum change required to solve this?** (Identify out-of-scope items and push them to `TODO.md` or separate tickets).
2. **Can this be tested in isolation?** (Identify the exact test file, command, or file state that will verify success).
3. **What codebase conventions does this touch?** (Cross-reference standard rules like `coding-behavior.md` or `git-worktree-hygiene.md`).

### 3. Generate the Ticket File
Create the ticket at `.tickets/open/dp-NNN_short-slug.md`.
- **Standard Tickets**: Use the standard subagent-ready template below.
- **Idea Tickets**: Use the `IDEA_TEMPLATE.md` template (brain-dump style). Set the status to `IDEA`, set Branch to `-`, and populate with pitch/context, thoughts, and next steps to graduate.

### 4. Handoff to JiranitorRex

The scaffolded ticket file is ready. JiranitorRex will handle all subsequent operations (gating, BACKLOG.md registration via BacklogRefiner, CHANGELOG.md sync). You may now submit this file to JiranitorRex for gate checks and execution.

Note: `ticket-creator` no longer writes BACKLOG.md directly. See `.agents/rules/backlog-write-ownership.md` for the centralization rule.

### 5. Sync configs (pre-commit)
If the ticket changes any agent/skill configs, run `uv run python scripts/sync_agent_configs.py` and `uv run python scripts/sync_dotfiles.py`.

---

## Subagent-Ready Ticket Template

```markdown
# [dp-NNN] Title

**Status:** OPEN
**Area:** Path to affected directories/files (e.g. dotfiles/.claude/, src/core/)
**Branch:** `ticket/dp-NNN-short-slug`
**Opened:** YYYY-MM-DD
**Closed:** -

---

## Description

What needs to be built or decided, and why it matters.

---

## Acceptance criteria

_Each criterion must be verifiable by a command, test, or observable file state. Avoid vague terms._

- [ ] Criterion one (e.g., `uv run pytest tests/test_module.py` passes)
- [ ] Criterion two (e.g., file `X` has property `Y`)

---

## Subagent Prompt Spec

_This section is designed to be parsed directly as the prompt for a spawned worker agent (like `cavecrew-builder`). It provides self-contained context and verification instructions._

### Role
You are a surgical code editor implementing ticket dp-NNN.

### Context
- Affected area: `<area>`
- Key files to read: [filename](file:///path/to/file)

### Instructions
1. Run baseline verification:
   ```bash
   uv run pytest
   ```
2. Apply modifications to target files to satisfy the acceptance criteria. Follow the Python styling rules in `coding-standards-python.md`.
3. Verify changes:
   ```bash
   uv run pytest <test_file>
   ```

---

## Implementation notes

_Approach, dependencies, known constraints._

---

## Closing notes

_Populate when closing. What was done, what surprised you._

---

## Changelog update

What to add to CHANGELOG.md when this closes.
```

---

## Subagent-Ready Idea Ticket Template

```markdown
# [dp-NNN] Title (Idea)

**Status:** IDEA
**Area:** Path to affected or proposed directories/files (e.g. dotfiles/.claude/, src/core/)
**Branch:** -
**Opened:** YYYY-MM-DD
**Closed:** -

---

## Pitch & Context

What is this idea? Why does it matter, and what problem does it solve?

---

## Brain Dump & Thoughts

A place to record initial thoughts, raw notes, or loose design ideas. Not yet structured into criteria or code plans.

---

## Next Steps to Graduate

What needs to be answered or done to turn this into an actionable ticket? (e.g., draft acceptance criteria, verify technical feasibility, identify target files).

- [ ] Define precise acceptance criteria
- [ ] Determine subagent role and prompt instructions
```
