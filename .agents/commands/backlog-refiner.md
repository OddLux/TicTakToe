---
name: backlog-refiner
version: 1.0.0
description: >
  Run Backlog Refiner v3 as a /loop session. Processes tickets one-by-one,
  promotes to folder structure (lazy), updates 4-signal confidence scores,
  and executes one-shot-ready tickets via worktree agents.
  Usage: /backlog-refiner [front|back|dp-NNN,...] [--dry-run] [--force-all] [preset]
  Flags:
    front (default): process queue from lowest dp-NNN to highest
    back: process queue from highest dp-NNN to lowest
    dp-NNN,...: explicit comma-separated ticket list
    --dry-run: alias for refine-only preset (standard_threshold=101, unreachable by design); analysis only, no one-shot executions. Note: TICKET.md confidence fields ARE written so scores persist across runs.
    --force-all: override 10-ticket cap (max 20)
  Presets (say any trigger phrase):
    aggressive: "go fast", "burn through it", "trust the scores", "max throughput"
    balanced:   "default", "normal run", "standard mode", "balanced" (DEFAULT)
    conservative: "careful", "low risk", "don't touch much", "conservative"
    refine-only: "just score", "analysis only", "no execution", "dry run"
  Natural language overrides (composable on any preset):
    "do N tickets" / "cap at N" -> max_tickets=N
    "oldest first" / "newest first" -> direction
    "leave X% buffer" -> budget_reserve_pct=X
    "execute at confidence X" / "threshold X" -> standard_threshold=X
    "virgin threshold X" -> virgin_threshold=X
    "max N analyst passes" -> research_pass_cap=N
    "treat all tickets equally" / "no virgin penalty" -> virgin_threshold=standard_threshold
---
Spawn the backlog-refiner agent to run a loop-native backlog refinement session.
