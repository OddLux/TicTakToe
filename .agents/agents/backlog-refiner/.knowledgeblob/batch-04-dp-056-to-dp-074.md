---
session: 2026-06-18_backlook-loop
batch: 04
scope: dp-056 through dp-074 (15 tickets, skip missing IDs)
tickets_scored: 15
---

## Findings

**Tier breakdown (Batch 4):**
- one-shot: 0
- sonnet-ready: 0
- needs-research: 8 (dp-057, dp-066, dp-067, dp-069, dp-070, dp-071, dp-072, dp-074)
- not-ready: 7 (dp-056, dp-058, dp-060, dp-061, dp-062, dp-063, dp-064)

**Confirmed superseded:**
- dp-064: git commit identity (git-branch-hierarchy.md v2.0.0 section 5, blank AC)
- dp-060: session naming standard (goal-lifecycle v1.3.0 + /set-goal)
- dp-071: BacklogRefiner v2 spawn interactions (v3.1 supersedes)

**Architecture conflicts (require AC rewrite):**
- dp-058: git status indicator -- subprocess ban in statusline (sidecar redesign needed)
- dp-063: Gemini statusline docs -- Claude cannot write Antigravity files (read-only only)

**Lowest score ever: dp-064 at 12/100** -- blank AC template, confirmed superseded.

## Key Pattern: "Architecture Orphans"

dp-058 and dp-063 both represent tickets that were written BEFORE a protocol rule was
established that makes their original approach impossible:
- dp-058 written before statusline-ux-constraints.md banned subprocesses
- dp-063 written before agent-environment-ownership.md banned cross-provider writes

These are Architecture Orphans: tickets whose implementation plan was invalidated by
a later protocol decision. The fix is not to close them (the underlying need is real)
but to rewrite the AC to work within the new constraints.

This is a new pattern -- previous batches had "Wishful Ticket" (feature shipped) and
"Verification Drought" (code exists but unverified). Architecture Orphans need
AC rewrites, not closures.

## Spontaneous Thoughts

- dp-061 (rebrand to "Agent Harness") is the wildcard ticket of the session so far.
  If the rebrand is real, it cascades changes across the entire repo. If it's just
  aspirational ("maybe someday"), it's a planning ticket that should be closed or
  converted to a DECISIONS.md entry. The ticket can't be refined without a human
  decision -- but the human may not even remember writing it.

- dp-069 (visual snapshot testing) is the best-planned ticket in Batches 3 and 4 combined:
  9/9/9 on info/ac/impl. It has an implementation-plan.md already written. Only kb_cov
  drags it down. This is the clearest "ready to spawn" ticket encountered so far --
  once pre-flight clears, a builder agent could execute this in one shot.

- dp-072 (CLI cross-agent dispatch) is ambitious but well-specced. It would be the
  most significant new feature in any batch so far. Worth flagging as a "future session
  focus" candidate once dp-069 and other near-ready tickets are cleared.

## Flags for Human Review

1. **dp-064** -- CLOSE IMMEDIATELY. 12/100, blank AC, confirmed superseded.
2. **dp-060, dp-071** -- High-confidence close candidates. Verify and close.
3. **dp-058** -- Sidecar redesign. Real underlying need; just wrong implementation plan.
4. **dp-063** -- Scope rewrite to read-only. Claude diagnosis only; Antigravity fixes.
5. **dp-069** -- Near-ready. Pre-flight check, then spawn CavecrewBuilder.
