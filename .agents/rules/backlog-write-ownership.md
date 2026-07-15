# Version 1.0.0

# BACKLOG.md Write Ownership

Single owner: `BacklogRefiner` (via native session output regeneration).

## 1. The Rule

Only `BacklogRefiner` may write/update `BACKLOG.md`. All other agents, skills, and the main thread are banned from touching it.

## 2. Banned Writers

- `ticket-creator` skill (removed from step 4 via dp-083)
- `JiranitorRex` (creates `.tickets/open/dp-NNN.md` only, does NOT write BACKLOG.md)
- Builder agents / implementors
- Main thread (except manual `/backlog-refiner update` invocation)

## 3. When BACKLOG.md is stale

BACKLOG.md is regenerated as part of each BacklogRefiner refinement session. No separate on-demand script. If BACKLOG.md drifts from ticket directory state, run BacklogRefiner or invoke `/backlog-refiner update`.

## 4. Lock-file Singleton Pattern

BacklogRefiner uses advisory lock file (`.claude/worktrees/backlog-refiner.lock`) to prevent concurrent runs:
- Startup: check if lock file exists. If yes, print BLOCKED and exit.
- On start: write lock file.
- On completion: delete lock file.
- Orchestrator rule: before spawning BacklogRefiner, check for lock file. Refuse spawn if present.

This is an advisory pattern (no OS enforcement) sufficient for single-user controlled spawning.

## 5. Rationale

Multiple agents writing BACKLOG.md in parallel causes git merge conflicts. Centralizing writes to one agent (BacklogRefiner, which runs serially) eliminates the conflict vector.
