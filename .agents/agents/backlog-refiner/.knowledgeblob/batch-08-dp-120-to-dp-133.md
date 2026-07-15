---
session: 2026-06-18_backlook-loop
batch: 08
scope: dp-120 through dp-133
tickets_scored: 15 (includes dp-130 collision, dp-131 collision)
---

## Findings

Batch 8 is the MOST RECENT tickets. Avg 66.2/100 -- second highest batch.
Mix of concrete, well-scoped work (dp-120, dp-121, dp-127) and pure IDEA stage
tickets (dp-122, dp-123, dp-124, dp-129, dp-132, dp-133).

### Score Distribution
- one-shot: none
- sonnet-ready (80-94): dp-120 (90), dp-121 (88), dp-126 (87), dp-127 (87), dp-130 (84) -- 5 tickets
- needs-research (60-79): dp-125 (77), dp-128 (77), dp-131a (61), dp-131b (62) -- 4 tickets
- not-ready (0-59): dp-122 (46), dp-123 (39), dp-124 (36), dp-129 (59), dp-132 (48), dp-133 (52) -- 6 tickets

### Average Score: 66.2/100

## Notable Tickets

dp-127 (87/100): PERFECT INFO + AC + IMPL scores (25/25/25). Crystal clear bug:
hooks use relative paths, CWD drifts, hooks fail. Exact fix shown in ticket.
Fastest win in the entire session backlog.

dp-121 (88/100): Statusline screenshot CI with SSIM. Excellent spec: SSIM tolerance
thresholds defined (0.98=PASS, 0.95-0.98=WARN, <0.95=FAIL), exit codes specified,
capture time <100ms requirement. Very implementable.

dp-126 (87/100): TodoRaider already exists as agent definition (.agents/agents/TodoRaider.md
v1.0.0). This ticket = verification + test coverage pass. Near-trivial implementation.

## IDEA Cluster (6 tickets)
dp-122, dp-123, dp-124, dp-129, dp-132, dp-133 all in IDEA status with poor AC.
These form a "futures cluster" -- creative concepts that need design sessions before
any agent can implement. Grouped recommendation: run a "IDEA graduation session"
where each gets either: (a) a design decision + concrete AC, or (b) explicitly marked
WONTFIX/deferred.

The dp-123+dp-124 pair (harness attachment + bidirectional sync) must be co-designed.
They're deeply interdependent and neither can be implemented without the other's design.

## ID Collisions
- dp-130: both directory (TICKET.md) and standalone .md. Consolidate to directory.
- dp-131: jobsdone metric vs session packages epic. Different scope entirely.

## Spontaneous Thoughts

dp-127 (hooks CWD fix) is the fastest win in the entire session. Exact JSON config
snippet shown in ticket. An agent could implement this in under 5 minutes. Why hasn't
it been done? Possible answer: it was created in a rapid-fire session and the human
never explicitly asked an agent to close it.

dp-130 (Antigravity statusline GeminiDir bug) is architecturally tricky: the bug is
in an external CLI (Antigravity) that dev-protocol doesn't own. Best-case: workaround
via env var. But the ticket is scored sonnet-ready because the diagnostic work is
complete and the path to resolution is clear.

dp-133 (caveman preprocessing / inference cost guard) naming collision with caveman
communication skill is a serious problem. "Caveman" means something specific here
(the communication compression mode). A "caveman inference cost guard" would cause
massive cognitive confusion. Rename to "inference-cost-guard" before any work.

## Flags for Human Review
- dp-127: FASTEST WIN -- implement immediately if wanted
- dp-121: high-value statusline CI that enables many future tickets (dp-117 depends on it)
- dp-130: external dependency clarification needed
- dp-122, dp-123, dp-124, dp-129, dp-132, dp-133: IDEA graduation session needed
- dp-133: RENAME required before implementation

## Pattern Registry Final Update (13 patterns total)
1. Shipped But Not Closed
2. Pre-Flight Check Gap
3. Wishful Ticket
4. Verification Drought
5. Architecture Orphans
6. IDEA Status Paralysis
7. Ownership Boundary Violation (OBV)
8. Arch Conflict - Staging Branch Phantom
9. Historical Audit Tickets
10. Design Prerequisite Gridlock
11. OBV Cluster in Statusline (sub-pattern of 7)
12. ID Collision Epidemic
13. Futures Cluster (IDEA tickets needing graduation session)
