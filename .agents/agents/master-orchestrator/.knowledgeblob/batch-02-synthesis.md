---
session: 2026-06-18_backlook-loop
batch: 02
scope: dp-021 through dp-037
cumulative: 28 tickets
---

## Orchestration Observations

Batch 2 avg 24/100 vs Batch 1 avg 51.4/100. Signal: older tickets decay fast.
Staleness -> ambiguity -> low specability. Backfill tasks (dp-025/026/027) cluster
near the low end; likely completed in flight without ticket closure.

3 sonnet-ready tickets (dp-030, dp-033, dp-036) all statusline-domain. Pre-flight
verification required before spawn -- high "wishful ticket" probability. Dispatch
StatuslineEngineer AUDIT first; read output before committing builder time.

## Signal Tracking Update

Cumulative 28 tickets:
- one-shot:       0
- sonnet-ready:   3  (all statusline; verify-before-spawn flagged)
- needs-research: 13
- not-ready:      12
- superseded-candidates: dp-011, dp-023, dp-024, dp-029, dp-037 (5 total)

Domain heat map (kb_coverage signal):
- statusline: 7-9/25 hits -- oversaturated; dedup pass needed before any new spawn
- other areas: near-zero -- backlog is statusline-heavy, not representative of full scope

## Cross-Batch Patterns (new this batch)

1. Wishful Ticket: feature specced cleanly but shipped before ticket closed.
   Candidates: dp-030, dp-033, dp-036. Pattern = spec exists, impl may be live.
   Fix: add "verify current state" as mandatory AC item 0.

2. Blocked-by-Convention: dp-022 hit no-clone rule at architecture level.
   Not a readiness gap -- the ticket's premise conflicts with protocol.
   Needs HUMAN ruling, not research.

3. Backfill Decay: dp-025/026/027 are historical hygiene tasks. May be done,
   may be partial. Git log check is the correct gate -- not agent execution.

4. Human-only gate: dp-034 requires elevated terminal. Agent cannot execute;
   mark HUMAN-ONLY in ticket, not needs-research.

## Systemic Issues

- No "verify current state" AC in older tickets -> Wishful Ticket risk on every
  implementation-targeting dispatch.
- NEEDS-HUMAN bucket missing from scoring rubric. Currently collapsed into
  not-ready; should be distinct (arch-conflict vs under-specced are different blockers).
- Superseded candidates accumulating without closure. 5 flagged across 2 batches;
  none formally closed. TicketReaper pass recommended after batch loop completes.

## Recommendations for Next Batches

1. Pre-flight check: before spawning any statusline-domain ticket, run
   StatuslineEngineer AUDIT. Cache result; reuse for dp-030, dp-033, dp-036 together.
2. Add HUMAN-ONLY tier to scoring output for future batches.
3. Batch-close superseded candidates (dp-011, dp-023, dp-024, dp-029, dp-037)
   via JiranitorRex in a single pass after loop end -- avoid per-ticket overhead.
4. Git log grep for dp-025/026/027 completion signals before marking needs-research.

## Spontaneous Notes

- dp-037 (/backlog-refiner command): BacklogRefiner v3.1 exists and is active.
  Command almost certainly shipped. Single `ls .agents/commands/` check closes it.
- dp-022 (no-clone conflict): worth a DECISIONS.md entry -- this is a recurring
  arch constraint that other future tickets may hit.
- Batch 1 vs Batch 2 quality gap suggests a natural "inflection ticket" exists
  somewhere in dp-015 to dp-021 range. Worth noting for batch-loop summary.
