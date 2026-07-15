---
name: resume-interrupted
description: >
  Ultra-low-cost session recovery. When interrupted (misclick, timeout, limit),
  use this single-line prompt to checkpoint from git + filesystem state.
  Agent infers task from uncommitted changes and open tickets, reports state,
  resumes. ~12-15 inference tokens. Use when session is cut and you need to
  pick up where you left off.
version: 1.0.0
status: experimental
runs: 0
last-run: never
upgrade-conditions:
  - "git workflow changes"
  - "ticket format changes"
---


Minimal prompt for resuming an interrupted session. Leans on git state + ticket
index instead of context recap-agent self-checkpoints and infers the task.

## When to Use

- Terminal still open, files untouched, but chat was cut (misclick, timeout, token limit).
- User wants to resume without typing a recap.
- Inference cost must stay minimal.

## The Prompt

Paste this when you need to resume:

```
Resume: git status, diff, tickets. Infer task. Report state.
```

That's it. **~12-15 inference tokens total.** Agent will:

1. Run `git status` (what changed)
2. Run `git diff HEAD` (what code changed)
3. Scan `.tickets/open/` (active work units)
4. Cross-ref with uncommitted changes
5. Infer what was in progress
6. Report current state + blockers
7. Proceed to resume work

## Why This Works

- **Git is a checkpoint.** Uncommitted files + open tickets encode the task.
- **Tool calls are free.** `git status`, `git diff`, file reads cost nothing vs.
  context explanation.
- **Inference minimal.** Only natural-language directive is needed; agent does
  the detective work.

## Variants

Tighter (risky):
```
Resume: git+tickets, infer task, report.
```

Safer (adds context):
```
Resume interrupted. Check: git status, diff, .tickets/open/. 
Infer task. Report state + blockers. Proceed.
```

Stick with the main prompt above-it's the sweet spot.
