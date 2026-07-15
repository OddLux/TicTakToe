---
session: 2026-06-18_backlook-loop
batch: 01
scope: dp-003 through dp-020
tickets_scored: 14
---

## Findings

**Tier breakdown (Batch 1):**
- one-shot: 0
- sonnet-ready: 0
- needs-research: 7 (dp-003, dp-005, dp-009, dp-011, dp-012, dp-015, dp-018)
- not-ready: 7 (dp-006, dp-008, dp-013, dp-016, dp-017, dp-019, dp-020)

**Supersession candidates:** dp-011 (playbooks shipped — high confidence)
**Stale candidates:** dp-003, dp-006, dp-008, dp-016 (scope mismatch or roadmap drift)
**NEEDS-HUMAN (scope decision):** dp-006, dp-008, dp-013, dp-016, dp-017, dp-019

## Key Pattern: "Shipped But Not Closed"

dp-011 (playbooks) and likely dp-012 (decision logging) are features that
have shipped but the tickets remain open. This is a hygiene problem in the
oldest cluster — the harness has evolved significantly past these tickets.
Expected to see more of this pattern as we progress.

## KB Coverage Gap

Nearly all oldest tickets (dp-003 to dp-020) have kb_cov scores of 2-10/25.
The .agents/knowledge/ vault has grown significantly AFTER these tickets were written.
Batch 1 has 0 tickets that scored kb_cov > 15/25.

This matters: higher kb_cov enables agents to self-orient when executing.
Action for later: flag this gap in session final observations.

## AC Quality Observation

Oldest tickets have "aspirational" AC phrasing ("workflow documented", "users can...",
"implementation notes provide detailed steps..."). These are descriptions of the
TICKET content, not verifiable success criteria for implementation.
Pattern: older tickets use AC as a spec walkthrough, not as test cases.

## Spontaneous Thoughts (may be wrong)

- Hypothesis: tickets dp-003 through dp-020 may represent an earlier phase where
  dev-protocol was more about documentation strategy than agentic automation. The
  harness has since evolved toward agent-ready specs, making these early tickets
  feel architecturally mismatched.

- dp-012 (decision logging) is interesting: 78/100 but the feature is live.
  The score is depressed partly because the two-tier system is live but
  the ticket's AC doesn't verify it's live. This may represent a scoring artifact —
  high-quality tickets written before the implementation, then not updated after.

- dp-019 (absorption flow) might be the most ambiguous: it's claiming to define
  a convention around /save-knowledge but says "no tooling needed." If /save-knowledge
  is already the implementation, this ticket is just asking for a docs paragraph.
  Worth flagging: many "not-ready" tickets may actually be "not-ready docs tasks."

## Flags for Human Review

1. **dp-011** — Very likely closeable. Playbooks feature is live, command works,
   .agents/playbooks/ has content. Recommend human verify and close.
2. **dp-003, dp-006, dp-008** — Roadmap clarity needed. These are "maybe someday"
   tickets that may never become relevant for a Python-first single-dev tool.
3. **dp-016** — Cross-provider boundary issue. Ghostty on Windows 11 + Antigravity
   statusline outside Claude scope. Likely close or split.
