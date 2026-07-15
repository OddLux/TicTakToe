---
session: 2026-06-18_backlook-loop
type: final-observations
---

## What This Session Set Out To Do

Full-pass scoring of every open ticket (dp-003 to dp-133) in a single session.
4-signal rubric. Gap analysis. AC improvements. No execution.

## What Was Actually Accomplished

8 batches scored. ~116 tickets evaluated. 13 patterns documented. Two one-shot
candidates found. 9 ID collisions flagged. ~116 per-ticket scoring files written.
Both knowledgeblobs populated with dense checkpoint data.

dp-087 was skipped by Haiku in batch 05 and needs re-score.

## The Biggest Finding

**Quality gradient is real and dramatic.** Oldest tickets (~dp-003 to dp-055) average
~28/100. Newest tickets (~dp-108 to dp-133) average ~70/100. The project has been
getting significantly better at writing tickets over 133+ iterations.

Implication: TicketReaper should be run on the old cluster (dp-003 to dp-055) to
clear superseded/stale tickets. The investment in improving those old tickets is low
return; better to close them and focus on the 70% quality range.

## The Most Surprising Finding

9 ID collisions in the ticket system. This is a data integrity problem. The ticket
system has no enforcement on ID uniqueness. JiranitorRex was introduced to fix this,
but the collisions predate JiranitorRex's shipping.

Hypothesis: the collisions happened in rapid-capture sessions where two agents or
the user and an agent created tickets simultaneously without checking the sequence.

## The Most Actionable Finding

dp-127 (hooks fail when CWD drifts). Score 87/100 with 25/25/25/12 breakdown.
Exact fix is in the ticket (JSON snippet with absolute paths). This could be closed
in a 5-minute builder agent pass. The only reason it hasn't been done is that it
was created and immediately forgotten.

## Patterns That Matter Most

**Pattern 7 (OBV) + Pattern 11 (OBV Statusline Cluster):** The agent-environment-ownership
rule was added AFTER many statusline tickets were written. Six tickets have Antigravity
AC items that violate the rule. These need cleanup but not deep research -- just remove
the Antigravity scope from each.

**Pattern 10 (Design Prerequisite Gridlock):** Multiple tickets are blocked on
decisions the human hasn't made. These aren't bad tickets; they're tickets waiting
for a product decision. One design session could unblock 4+ tickets simultaneously.

**Pattern 12 (ID Collision Epidemic):** 9 collisions. This is the most urgent structural
debt. It makes the ticket system unreliable as a reference. File a JiranitorRex
renumbering task immediately.

## Spontaneous End-of-Session Thought

The council meta-deadlock is interesting: the summon-the-council skill (dp-115b)
doesn't exist yet, so the council can't be formally summoned to make the design
decisions that would unblock dp-092, dp-094, dp-097, dp-100. But those decisions
could also be made informally by the user. The tool isn't a requirement -- just
saying "I've decided: reset countdown red = urgent (soon), green = safe (far away)"
resolves dp-092. The tickets make it seem like formal council approval is required,
but most of these are one-person judgment calls.

## What I'd Do Differently Next Time

1. Pre-score pass: run TicketReaper FIRST on dp-003 to dp-055 to clear stale/superseded.
   Would have cut ~30 tickets from scope and increased average quality.
2. ID collision detection at batch start: grep for duplicate IDs before scoring.
   Save 2+ hours of collision documentation.
3. Batch size 15 instead of 10: allowed parallel scoring of 2 batches simultaneously.
   This worked well and should be the default batch size going forward.
4. Score MO synthesis in parallel with per-ticket file writing (did this in batches 5+).
   Good pattern to carry forward.

## Loose Ends

- dp-087: unscored, re-score next session
- dp-107: verify commit 3fdf8c4 and close if confirmed
- dp-091: run pytest and close if passes
- 9 ID collisions: file JiranitorRex renumbering task
- OBV cleanup: 6 tickets need Antigravity AC removed
