---
name: save-knowledge
description: >
  Distills current session context into a persistent reference note in
  .agents/knowledge/. Use at the end of a feature or significant work session
  to capture how something works, design patterns, and gotchas not obvious
  from the code alone.
version: 1.0.0
status: experimental
runs: 0
last-run: never
upgrade-conditions:
  - "knowledge base file naming conventions change"
---

# Save Knowledge

Creates or updates a reference document in `.agents/knowledge/` explaining HOW
a feature or subsystem works - data flows, key design patterns, edge cases, and
non-obvious implementation details. These notes exist so future agents and
contributors do not re-derive context from code alone.

## When to invoke

- End of a feature or task session
- When something non-obvious was discovered, designed, or debugged
- When the user says "save this", "capture this session", "add to knowledge base"
- After closing a ticket, to preserve the reasoning behind the implementation

## Instructions

### 1. Identify the topic

Determine a narrow, specific topic from the conversation. Prefer specificity:
`sequence-detection-heuristic` over `core-system`.

Filename: `.agents/knowledge/<topic-slug>.md`

If a file for this topic already exists, update it - do not create a duplicate.

### 2. Extract the content

From the conversation, extract:

- **What it is** - one paragraph: what this component does and what problem it solves
- **How it works** - key logic, data flows, or decision paths; enough detail that
  a reader could understand without reading the full git history
- **Key design choices** - deliberate decisions baked into this component
- **Gotchas / non-obvious behavior** - anything that would surprise a code reader
- **Related tickets** - IDs that drove this work

Do not copy raw code blocks unless a short snippet (≤ 15 lines) clarifies
something prose alone cannot.

### 3. Write the file

```markdown
---
topic: <slug>
area: <module or logical area>
tickets: [dp-NNN]
updated: YYYY-MM-DD
---

# <Topic Title>

One-paragraph description of what this is and what problem it solves.

## How it works

...

## Key design choices

...

## Gotchas / non-obvious behavior

...

## Related

- Tickets: dp-NNN
```

Use today's date in `updated`. Leave sections blank rather than filling with
filler - omit a section entirely if there is nothing to say.

### 4. Quality bar

Before writing, ask: "Would a developer reading this file understand the
component without needing to re-run the conversation?" If no, add more context.

Avoid restating what well-named code already clearly says.

### 5. Do not commit automatically

Stage the knowledge file alongside the work it documents, or use `/commit-changes`.
