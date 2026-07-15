---
name: summon-the-council
description: >
  Structured multi-agent design deliberation session. Agenda-driven. Each item gets context,
  debate, verdict, and either a ticket stub or a decision log entry. Ends with session-handover.
  Wraps MasterOrchestrator decomposition, ConventionSentinel compliance scan, and optional
  ProjectGrandmaster history check. Output: session package in .agents/sessions/.
  Trigger: "summon the council", "/summon-the-council", "council meeting", "let's have a council
  vote", "gather the council", "council deliberation".
version: 1.0.0
status: ready
runs: 0
last-run: never
upgrade-conditions:
  - "new council member agents added"
  - "session-handover format changes"
  - "ticket-creator protocol changes"
---

# Summon the Council

A council session is a structured design deliberation. Invoked when protocol changes,
architectural decisions, or new agent designs need multi-perspective review before committing.

This skill formalizes what happens organically in long design sessions: agenda, debate, verdict.

---

## When to Summon

- Proposing a new agent or skill that touches multiple existing systems
- Protocol changes with broad impact (rules, naming conventions, workflow triggers)
- Architectural decisions the agent is uncertain about (model routing, tool scoping)
- User explicitly requests council input: "what does the council think about X?"
- Inbox tickets that span 3+ systems

---

## Session Structure

### Phase 1: Agenda Construction
Before deliberating, build a structured agenda from the user's prompt:
```
## Council Agenda -- YYYY-MM-DD
1. [Item title] -- [proposer] -- [type: DESIGN | POLICY | REVIEW | NAMING]
2. ...
```
Cap: 10 items. If more, ask user to prioritize or split into sessions.

### Phase 2: Per-Item Deliberation
For each agenda item:

1. **Context** (1-3 sentences): what is this, why does it matter now?
2. **Arguments for** (bullet list, max 4): strongest case for the proposal
3. **Arguments against / risks** (bullet list, max 4): strongest counterarguments
4. **Council vote** (simulated): present 2-3 options as AskUserQuestion if genuine choice exists.
   If outcome is clear from context, skip vote and state the verdict directly.
5. **Verdict**: ADOPTED | DEFERRED | REJECTED | NEEDS-RESEARCH
6. **Action**:
   - ADOPTED -> file a ticket (dp-NNN via JiranitorRex) OR implement directly if micro-scope
   - DEFERRED -> brain dump to TODO.md with rationale
   - REJECTED -> log decision in `.agents/knowledge/decision-ledger.md` with rationale
   - NEEDS-RESEARCH -> spawn the appropriate research agent inline

### Phase 3: Session Documentation
After all items:
1. Print a **Council Summary** block: one line per item, verdict, action taken
2. Run `/session-handover` to package the session into `.agents/sessions/`
3. If 3+ tickets were filed this session, run `/make-new-build` (or note it's pending)

---

## Agent Routing (optional, for complex items)

| Need | Agent to spawn |
|------|---------------|
| Protocol compliance check | `ConventionSentinel` |
| Historical precedent check | `ProjectGrandmaster` |
| Code location research | `CavecrewInvestigator` |
| Duplicate/conflict audit | `CavecrewInvestigator` |
| Claude Code docs research | `claude-code-guide` |
| Cost analysis | `ProtocolCostAuditor` |

Spawn these only when the item genuinely needs external input. Most items resolve in the
main thread without spawning.

---

## Output Format

```markdown
## Council Session -- YYYY-MM-DD

### Agenda
1. [Item] -- [Type] -- [Verdict]
...

### Item N: [Title]
**Context:** ...
**For:** ...
**Against:** ...
**Verdict:** ADOPTED | DEFERRED | REJECTED | NEEDS-RESEARCH
**Action:** [ticket dp-NNN filed | decision logged | TODO.md brain dump]

---

### Council Summary
| Item | Verdict | Action |
|------|---------|--------|
| ... | ... | ... |

Session package: .agents/sessions/YYYY-MM-DD_<3-word>/
```

---

## Constraints

- No more than 10 agenda items per session
- Every ADOPTED item MUST have a corresponding action (ticket or direct implementation)
- Every REJECTED item MUST be logged in decision-ledger.md
- Session ends with `/session-handover` (crumbs or loaf per user preference)
- The agent running the council is the moderator -- present options, don't advocate for a specific outcome
