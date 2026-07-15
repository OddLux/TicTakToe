# Feedback: Visual Caveman Plan Summary Box

> Source: user feedback 2026-06-18
> Context: caveman summaries used as plan headers

---

## The Ask

When caveman is used to summarize a plan at the top of a document, the summary
block should be maximally compressed conceptually BUT visually rich in
presentation. Not just bullet points -- use ASCII structure to show shape.

## Core Idea

Plans have inherent structure: hierarchy, sequences, file trees, decision paths.
Caveman ultra compresses the WORDS. The visual layer compresses the SHAPE.
Both should happen together in plan header boxes.

## Visual Conventions to Apply

### File/folder trees -> use tree view
```
plans/
  state/
    git-state.md
    goal-state.json
  decisions/
    in-session.md
    deferred.md
```

### Sequences -> numbered with arrows
```
1. git state -> 2. tickets -> 3. crumbs -> 4. goal JSON -> infer -> report
```

### Decision paths -> branch notation
```
tier?
  quick  -> manifest + crumbs + git-state + in-flight
  standard -> +goal-state + decisions + ideas
  full   -> +loaf + agents + blobs + plan-state
```

### Signal/source maps -> table (2-col max)
```
git status    | code state, dirty files
crumbs.md     | goal, shipped, loose-ends
goal-state    | active banner + session_id
tickets/open/ | dp-NNN in-flight
```

### Causality -> arrows inline
```
session dies -> context lost -> package -> resume -> lossless
```

## Proposed Plan Header Box Template

```
┌─ PLAN: <title> ────────────────────────────────────┐
│ goal    : <8-word imperative>                       │
│ scope   : <N files> | <N tickets> | <tier>          │
│ sequence: step1 -> step2 -> step3                   │
│ touches :                                           │
│   path/to/file.md                                   │
│   path/to/other.py                                  │
│ gaps    : item1 | item2                             │
│ next    : <single next action>                      │
└────────────────────────────────────────────────────┘
```

## When to Apply

- Any document with a "plan" or "convention" scope
- Session packages (crumbs.md header)
- Skill/rule drafts with implementation sequences
- Anywhere caveman ultra summary is placed at the top of a working doc

## NOT for

- Casual chat responses (use inline ultra prose)
- Single-step tasks (box overhead not worth it)
- Terminal output (box chars may not render)
