---
session: 2026-06-18_backlook-loop
batch: 02
scope: dp-021 through dp-037
tickets_scored: 14
---

## Findings

**Tier breakdown (Batch 2):**
- one-shot: 0
- sonnet-ready: 3 (dp-030, dp-033, dp-036)
- needs-research: 5 (dp-025, dp-026, dp-027, dp-034, dp-035, dp-037) — 6 actually
- not-ready: 5 (dp-021, dp-022, dp-023, dp-024, dp-029)

**Supersession candidates:** dp-029 (release cadence in AGENTS.md), dp-024 (/onboard),
dp-023 (existing Windows playbooks), dp-037 (command stub may exist)
**NEEDS-HUMAN:** dp-021 (caching scope), dp-022 (no-clone constraint)

## Key Pattern: "Pre-Flight Check Gap"

Batch 2 introduces a new pattern: tickets that have STRONG SPECS but need a quick
verification that the feature isn't already implemented before committing to work.

dp-030, dp-033, dp-036 all have good AC but StatuslineEngineer / v4 statusline
may have already addressed their scope. ALL THREE have the same gap: no "verify
current state" step in AC.

This is a broad pattern: tickets from this era were written anticipating future
work, then the work happened, but the ticket wasn't updated. I'm calling this
the "Wishful Ticket" pattern — specs written for future states that are now past.

## Score Inflation from Good Specs

Batch 2 average score: ~24/100. Lower than Batch 1 (51.4/100). But the 3 sonnet-ready
tickets all have scores of 33-34 — good specs, just need pre-checks.

The KB coverage (kb_cov) is notably higher for statusline tickets (7-9/25) vs.
other ticket areas (2-4/25). This tracks: we've done a lot of statusline work and
built up corresponding KB. Areas with no KB coverage tend to be the "someday" tickets
(dp-021 caching, dp-022 cross-project, dp-023 MCP).

## Spontaneous Thoughts

- The three sonnet-ready tickets (dp-030, dp-033, dp-036) are ALL statusline tickets.
  The statusline work is the most mature, most specced area of the project. Yet we
  ALSO have the most potential "already done but not closed" issues there. This is
  a documentation/closing hygiene failure specific to the statusline epic.

- dp-034 (purge caches) is interesting: it's a one-time device-local task that
  doesn't fit the "ticket" model well. It shouldn't be a recurring ticket. Once done,
  close. But the agent can't run it (needs elevated terminal). This is a class of
  ticket that's only resolvable by human action.

- dp-029 (feature version bump rule): This is almost certainly superseded.
  AGENTS.md's "Release Cadence (non-negotiable)" section was written precisely to
  document this rule. Ticket may be from before that section existed.

## Flags for Human Review

1. **dp-030, dp-033, dp-036** — Statusline "Wishful Tickets." Run pre-flight greps.
   If features are live, batch-close all three.
2. **dp-021** — "Caching layer" must be defined before any agent can help.
3. **dp-022** — Architecture conflict with no-clone rule. Likely not implementable as-written.
4. **dp-034** — Human must run elevated PowerShell to execute. Agent cannot.
