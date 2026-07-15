# Version 1.0.0

# Agent Self-Ticketing

Always-on convention. When an agent encounters a **side issue** during a task,
it must decide - by confidence - whether to file a `dp-NNN` ticket
autonomously or to leave a brain dump. It must never fix the side issue
inline.

The point: keep agents on their primary objective while ensuring real,
separate problems are captured in the markdown harness (TICKET_TEMPLATE.md,
BACKLOG.md, the `ticket-creator` skill) instead of becoming inline
distractions or getting lost.

---

## 1. What Counts as a Side Issue

A problem the agent notices that is **outside the acceptance criteria of the
current task or goal**. Examples: a latent bug in adjacent code, a missing
test, a convention violation, a broken doc link, dead code, an undocumented
field. It is *not* the thing the agent was asked to do.

If the problem is part of the current task's acceptance criteria, it is not a
side issue - fix it as normal.

---

## 2. Confidence Threshold (60-70%)

Score the side issue against three heuristics:

- **(a) Real and reproducible** - a reproducible error or a clear missing
  behavior, not a stylistic preference or a guess.
- **(b) Separate from the goal** - distinct from the primary goal's
  acceptance criteria; fixing it is not required to finish the current task.
- **(c) Broad impact** - likely to affect multiple future sessions or agents,
  not a one-off cosmetic nit.

Mapping:

| Heuristics met | Confidence | Action |
|----------------|-----------|--------|
| Two of three | ~60% | **At threshold -> file a ticket** |
| All three | 70%+ | **Above threshold -> file a ticket** |
| One or none | < 60% | **Below threshold -> brain dump only** |

At or above 60%, the agent MUST file a ticket. Below 60%, it MUST NOT file a
ticket - it appends a one-line brain dump to `TODO.md` and nothing more.

---

## 3. No Inline Fix - No Matter What

Even at 90% confidence, if the side issue is outside the current goal's scope,
the agent does **not** fix it inline. It files the ticket (or brain dumps) and
returns to the primary goal. This is absolute - it overrides the urge to "fix
it while I'm here" (see `coding-behavior.md` #3, Surgical Changes).

---

## 4. Autonomous Ticket Creation Procedure

At or above threshold, create the ticket using the existing harness - same ID
sequence, same template, same registration as `ticket-creator`:

1. **Determine the ID.** Find the highest `dp-NNN` across `.tickets/open/` and
   `.tickets/closed/`, add 1, zero-pad to three digits. (Same logic as the
   `ticket-creator` skill.)
2. **Scaffold the file.** Create `.tickets/open/dp-NNN_<short-slug>.md` from
   `.tickets/TICKET_TEMPLATE.md`. Fill Description, verifiable Acceptance
   criteria, and Implementation notes from what was observed.
3. **Provenance line.** The Description block MUST include, as its first line:

   ```
   [auto-filed by: <model-id> during dp-NNN]
   ```

   `<model-id>` is the filing agent's model (e.g. `claude-opus-4-8`).
   The trailing `dp-NNN` is the ticket the agent was working on when it filed
   this one (the primary task), not the new ticket's own ID.
4. **Register in BACKLOG.md.** Add a row to the Open table.
5. **Resume.** Return to the primary goal immediately. Do not expand scope.

---

## 5. Below-Threshold Path

Under 60% confidence: append a single-line brain dump to `TODO.md` describing
the observation. No ticket, no BACKLOG entry, no inline fix. Per the
`TODO.md` lifecycle (AGENTS.md, Workspace), this can graduate to a ticket
later via `/triage-todos` if it proves real.

---

## 6. Relationship to Lock-In

The `/lock-in` skill is the focus-enforcement posture built on this rule.
While a goal is `in_progress` (goal-lifecycle rule), lock-in is the default
posture: side issues are routed through this rule rather than addressed. This
rule holds the threshold and procedure; lock-in holds the user-facing notice
and posture. No duplicate logic.
