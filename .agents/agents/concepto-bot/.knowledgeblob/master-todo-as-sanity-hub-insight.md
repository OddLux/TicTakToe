# master-todo-as-sanity-hub-insight

**Date:** 2026-06-18
**Concept:** MASTER_TODO.md reframed as project sanity hub, not just a list
**State:** crystallizing

## Stream

The framing shift happened in this prompt. Previously we were designing a "tag taxonomy."
Now the user has reframed it: MASTER_TODO.md is a *living sanity check mechanism*.
It's not a list you fill in. It's a continuous convergence loop.

The mental model: like a Google Doc with commit history.
- Human or agent writes a tag anywhere in the project
- Audit run picks it up, processes it, marks it handled
- Commit records the change
- Repeat. The doc gets cleaner each run.

This is actually closer to a kanban board than a TODO list.
The tags are the input tickets. MASTER_TODO.md is the board.
The commit history is the movement history.

Hyper-permissive input is the key design choice.
Tags can live:
- Inline in any .md file (decorators on the document)
- In dedicated TODO.md files anywhere in the folder structure
- Directly in MASTER_TODO.md itself

All paths converge to MASTER_TODO.md. That's the absorber.

The word "absorb" the user used is perfect. The doc absorbs.
It doesn't just list -- it pulls in, processes, and marks done.
After enough runs, everything is resolved or tracked.

## The H1 rendering bug (MasterOrchestrator catch)

Critical: `#TODO:NEW_FEATURE` at line start = H1 heading in every markdown renderer.
Fix: `- #TODO:NEW_FEATURE` (dash prefix).
This is a blocker that would have broken the convention immediately in practice.
The orchestrator caught it. Good use of the vet step.

## The audit loop vs confidence gate tension

MasterOrchestrator flagged this too.
agent-self-ticketing.md requires 60-70% confidence before filing a ticket.
`- #TODO:NEW_FEATURE` fires unconditionally (no confidence scoring).
These are in direct conflict.

Possible resolution: tags in MASTER_TODO.md are already human-curated.
By the time something is in MASTER_TODO.md, a human (or trusted agent) has
decided it's worth tracking. So confidence gate doesn't apply -- the human's
intention IS the confidence signal.

That's the key argument: tags in MASTER_TODO.md are post-curation, not raw signals.
The confidence gate applies to inline code scans (agent-self-ticketing).
The NEW_* tags are post-curation declarations.
These are two different layers of the same system.

## Shape so far

```
LAYER 1: Inline code scan (existing agent-self-ticketing.md)
  agent notices side issue -> scores confidence -> files ticket or brain dumps to TODO.md
  
LAYER 2: TODO.md brain dumps (existing AGENTS.md lifecycle)
  human writes to TODO.md -> /triage-todos converts to tickets
  
LAYER 3: NEW_* tag system (NEW -- being designed now)
  human/agent writes - #TODO:NEW_FEATURE to MASTER_TODO.md (post-curation)
  audit loop processes -> fires mapped workflow -> marks handled
  no confidence gate needed (human curated)
```

The three layers don't conflict -- they're sequential.
Layer 1 feeds Layer 2, Layer 2 feeds Layer 3.
The audit loop is the final processing stage.

## Still unresolved

- Who generates what-three-words slugs for agent subfolders?
- Does audit loop run on demand or on session start?
- Absorption run (TODO.md -> MASTER_TODO.md) -- how often, triggered by what?
- NEW_TICKET long-term fate
