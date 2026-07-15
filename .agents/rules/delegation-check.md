# Version 1.0.0

# Delegation Check

Before starting any implementation or research task, classify its tier.
Act only after classification.

## Tier Gate

| Tier | Criteria | Action |
|------|----------|--------|
| Micro | <=2 files, no multi-step reasoning, output in 2 sentences | Proceed inline |
| Standard | 3-5 files OR system understanding required OR >1 step | Spawn agent |
| Complex | >5 files OR cross-cutting OR novel reasoning | Grill user first, then spawn |

## Scope First

If the request does not name specific files, does not state expected output,
or spans more than one system: ask before starting.

Use `AskUserQuestion` to extract:
- What files or systems are involved
- What the expected output looks like
- Any constraints or exclusions

Do not assume scope and proceed. A clarifying question costs one turn;
a misdirected execution costs context budget.

## Bias on Tie

When a task sits on the Micro/Standard boundary: delegate.
Rationalization ("this one's quick") is how inline work grows.

## Exceptions

- User says "just do it", "inline", or "don't spawn" - proceed inline
- Skill invocations (`commit-changes`, `sync_agent_configs.py`, etc.) - no classification needed
- Read-only tasks: explanations, audits, questions with no side effects
- Continuation of already-running delegation work
