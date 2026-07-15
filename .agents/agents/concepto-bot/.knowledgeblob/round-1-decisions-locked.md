# round-1-decisions-locked

**Date:** 2026-06-18
**Concept:** Core format decisions from questionnaire round 1
**State:** crystallizing

## Locked decisions

### Separator: COLON (was typo in original proposal)
`#TODO:NEW_FEATURE` -- colon, not semicolon.
Consistent with taxonomy draft. Standard-looking. Confirmed.

### Meeting item name: NEW_COUNCIL_ITEM
`#TODO:NEW_COUNCIL_ITEM` -- harness-specific, maps to /summon-the-council agenda queue.
Not generic "meeting item" -- this project's meeting IS the council.

### Priority: Optional named suffix `:HIGH/:MED/:LOW`
`#TODO:NEW_FEATURE:HIGH` -- human-readable, optional (absent = no priority declared).
Scanner skips priority if not present. Does not fail on absence.
Full format: `#TODO:NEW_<TYPE>` or `#TODO:NEW_<TYPE>:HIGH` or `:MED` or `:LOW`

### Post-fire behavior: PENDING CLARIFICATION
User wants to clarify what "post-fire" means before deciding.
Key user constraint revealed: **only MASTER_TODO.md is editable in this session.**
All other documents are read-only. Tags likely live in MASTER_TODO.md only (for now).
This reframes the question: post-fire update goes back into MASTER_TODO.md, not into source files.

## Stream insight: MASTER_TODO.md as the living document

User framing: treat MASTER_TODO.md like a Google Doc with commit history.
This is actually a much cleaner mental model than "AI edits source files inline."
The flow becomes:
  - Write `#TODO:NEW_FEATURE:HIGH` in MASTER_TODO.md
  - AI processes it -> creates ticket dp-NNN
  - AI marks it in MASTER_TODO.md as handled (adds `[-> dp-NNN]` or similar)
  - Commit that change with a meaningful message
  - The commit history IS the audit trail

This is elegant. MASTER_TODO.md is the source of truth for pending work.
Source files stay clean. No inline tag pollution in actual code.
The "post-fire" question is really: what does the handled line look like in MASTER_TODO.md?

## Full format so far (locked)

```
#TODO:NEW_TICKET              (generic, any work item)
#TODO:NEW_FEATURE             (new capability)
#TODO:NEW_FEATURE:HIGH        (with priority)
#TODO:NEW_BUGFIX:LOW
#TODO:NEW_CHORE
#TODO:NEW_COUNCIL_ITEM        (-> council agenda)
#TODO:NEW_CONVENTION          (-> questionnaire-scribe)
#TODO:NEW_SKILL               (-> skill scaffold)
#TODO:NEW_AGENT               (-> agent scaffold)
#TODO:NEW_AUDIT               (-> audit trigger)
```

## Still unresolved

- Post-fire behavior in MASTER_TODO.md (what does a handled line look like?)
- Scanner ownership (TodoRaider upgrade vs new script)
- Scan trigger model (on-demand vs session start vs hook)
- Does NEW_TICKET stay as catch-all long-term or retire after typed versions proven?
- NEW_AUDIT -> which agent? (ConventionSentinel vs TodoRaider vs generic)
