---
session: 2026-06-18_backlook-loop
batches: 03+04
scope: dp-038 through dp-074
cumulative: 56 tickets
---

## Batch 3+4 Orchestration Observations

Batch 3 (dp-038..dp-055, 13 tickets): avg ~26/100. Zero one-shot. Pattern:
"Verification Drought" -- code/skill/playbook exists but no confirmed end-to-end
run. CavecrewBuilder commit discipline (dp-038), orchestration playbook (dp-039),
dotfiles-sync (dp-051), session-handover (dp-053) all fall here. Not broken by
design, broken by absence of a run witness.

Batch 4 (dp-056..dp-074, 15 tickets): avg ~26/100. Zero one-shot. Pattern:
"Architecture Orphans" -- tickets invalidated by protocol rules that arrived after
the ticket was written. dp-058 banned subprocess from statusline (arch-conflict),
dp-060 superseded by goal-lifecycle v1.3.0, dp-063 ownership-conflict (Claude
cannot write Antigravity files per agent-environment-ownership rule), dp-064 blank
AC + confirmed superseded (lowest score 12/100), dp-071 superseded by BacklogRefiner
v3.1.

## New Patterns Logged

VERIFICATION DROUGHT (Batch 3 primary): implementation land but no smoke test or
E2E witness committed. Tickets linger as "needs-research" with no clear path to
close. Fix signal: a ticket in this state needs a one-shot test-run AC rewrite +
TicketBouncer spawn, not a refinement pass.

ARCHITECTURE ORPHANS (Batch 4 primary): tickets written pre-rule-change that now
conflict with a later convention (subprocess ban, provider ownership split, v2
branch model). These are not refineable without human decision on whether to archive
or redesign. Tag: NEEDS-HUMAN.

LOWEST-SCORE ALERT: dp-064 at 12/100 -- blank AC, confirmed superseded. No path to
redemption. Close immediately, no bouncer needed.

## Signal Tracking Update (cumulative)

| Signal | Count (56 tickets) |
|---|---|
| one-shot | 0 |
| sonnet-ready | 3 (all Batch 2, statusline cluster) |
| needs-research | 29 |
| not-ready | 24 |
| confirmed-superseded | 10+ |
| architecture-conflicts | 3 (dp-046, dp-058, dp-063) |
| needs-human | 3 (dp-061, dp-063, dp-046) |
| running avg score | ~27/100 |

Zero one-shot across 56 tickets is a strong signal: backlog has accumulated without
a pruning pass. Superseded tickets alone account for ~18% of scored scope.

## Architecture Debt Register (conflicts found)

| Ticket | Conflict | Blocking Rule |
|---|---|---|
| dp-046 | scope ambiguous, possible arch conflict | unknown, needs read |
| dp-058 | subprocess call in statusline banned | statusline-ux-constraints.md + permission-model.md |
| dp-063 | Claude writing Antigravity dotfiles | agent-environment-ownership.md v1.4.1 |

All three require human decision before any builder can touch them. Route to
NEEDS-HUMAN queue. Do not spawn CavecrewBuilder on these.

## Top Candidates for Human Action

1. dp-064 -- CLOSE NOW. Blank AC + superseded. 12/100. No bouncer needed.
2. dp-060 -- CLOSE. Superseded by goal-lifecycle v1.3.0. Verified.
3. dp-049 -- CLOSE. Confirmed superseded by dp-107.
4. dp-071 -- CLOSE. Superseded by BacklogRefiner v3.1.
5. dp-063 -- NEEDS-HUMAN: ownership conflict. Redesign or abandon.
6. dp-058 -- NEEDS-HUMAN: arch conflict. Sidecar redesign required before impl.
7. dp-040 -- CLOSE or confirm: check if git-branch-hierarchy v2 §5 fully covers AC.

## Spontaneous Notes

- "Verification Drought" and "Architecture Orphans" are two distinct rot vectors.
  Drought = run it once to resolve. Orphans = human decision required.
- Batch 3 superseded tickets (dp-040, dp-047, dp-048, dp-049) cluster around git
  workflow evolution -- the worktree hygiene and branch hierarchy rewrites (v2.0.0)
  obsoleted a wave of tickets simultaneously.
- dp-069 (32/100 needs-research) is the highest-scoring Batch 4 ticket: 9/9/9 on
  info/ac/impl. If pre-flight check passes, it is sonnet-ready with minimal AC rewrite.
  Track as promotion candidate in Batch 5+ synthesis.
- Score floor across 56 tickets is 12 (dp-064). Score ceiling is ~32 (dp-066,
  dp-069). Ceiling is far below 60 (sonnet-ready threshold). Systemic, not outlier.
