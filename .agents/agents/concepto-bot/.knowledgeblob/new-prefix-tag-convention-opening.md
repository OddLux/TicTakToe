# new-prefix-tag-convention-opening

**Date:** 2026-06-18
**Concept:** `#TODO;NEW_*` inline tag convention -- flat namespace, action-oriented
**State:** raw

## Stream

User came in with a concrete counter-proposal to the 5-category hierarchy the council reviewed.
Instead of `#TODO:WORK_NEW_FEATURE:2` they want `#TODO;NEW_FEATURE`.
Two things immediately jump out: the semicolon instead of colon, and the flat namespace.

The flat namespace is actually the grandmaster's preference in disguise --
"ship the smallest thing, let real usage grow the vocabulary."
`NEW_` as a universal trigger prefix is elegant. Everything tagged `NEW_` means
"something should be created from this." The type suffix tells you *what* to create.

The semicolon is interesting. Could be intentional (disambiguates from the colon-based
code comment `# TODO: fix this`) or could be a typo. Need to confirm.
If intentional: `#TODO;NEW_FEATURE` -- the semicolon becomes the "fire this" separator.
If typo: revert to colon and we have `#TODO:NEW_FEATURE`.
Either way, the format is dead simple compared to `#TODO:CATEGORY_TYPE:priority`.

The proposed 9 types:
  NEW_TICKET      -- generic, catch-all work item
  NEW_FEATURE     -- new capability ticket
  NEW_BUGFIX      -- bug ticket
  NEW_CHORE       -- tooling/housekeeping ticket
  NEW_MEETING_ITEM -- something for council or a meeting agenda (name TBD)
  NEW_CONVENTION  -- trigger /questionnaire-scribe
  NEW_SKILL       -- scaffold a new skill
  NEW_AGENT       -- scaffold a new agent
  NEW_AUDIT       -- trigger an audit workflow

What I like about this list:
- The first 4 map directly to commit types: feature, bugfix, chore, (ticket = any)
- NEW_CONVENTION and NEW_SKILL and NEW_AGENT are harness-specific -- the system can grow itself
- NEW_AUDIT is a meta-tag: "this area needs eyes, spawn something to look at it"
- NEW_MEETING_ITEM is the fuzzy one -- is it a council agenda item? A standup note? A human-to-human thing?

~~Maybe NEW_MEETING_ITEM should just be NEW_COUNCIL_ITEM since this project's meeting format IS the council~~
But that's too harness-specific. A human reading the code would understand "meeting item" more than "council item."
Actually... in this project the council IS the meeting. NEW_AGENDA_ITEM? NEW_DISCUSSION?

The flat `NEW_` prefix means the scanner is trivially simple:
`grep '#TODO;NEW_'` catches everything. No dispatch table needed for basic scanning.
The type suffix determines routing after the fact.

What about priority? The council review had a whole debate. The user's proposal drops it entirely.
That's fine for MVP. Priority can be appended as an optional `:N` suffix later: `#TODO;NEW_FEATURE:2`
But for now, no priority = simpler, and the grandmaster would approve.

What about the replace-vs-append debate from the council?
With this simpler format, append feels right: `#TODO;NEW_FEATURE [-> dp-042]`
Leave the original tag visible so audit can see what fired.

Still unresolved: the semicolon question is the most important one to nail first.
Everything else flows from the format character.

## Shape so far

```
#TODO;NEW_TICKET        -> JiranitorRex: generic dp-NNN
#TODO;NEW_FEATURE       -> JiranitorRex: feature ticket
#TODO;NEW_BUGFIX        -> JiranitorRex: bugfix ticket
#TODO;NEW_CHORE         -> JiranitorRex: chore ticket
#TODO;NEW_MEETING_ITEM  -> ??? agenda queue (name TBD)
#TODO;NEW_CONVENTION    -> /questionnaire-scribe
#TODO;NEW_SKILL         -> skill scaffold template
#TODO;NEW_AGENT         -> agent scaffold template
#TODO;NEW_AUDIT         -> ConventionSentinel or TodoRaider re-scan
```

Priority: deferred (optional `:N` suffix, not required for MVP)
After firing: append `[-> reference]` inline, leave original tag
Scanner: `grep '#TODO;NEW_'` -- dead simple

## Still unresolved

- Semicolon `;` vs colon `:` -- intentional or typo? BLOCKING question #1
- `NEW_MEETING_ITEM` name -- council-specific or generic?
- `NEW_AUDIT` trigger -- which agent? ConventionSentinel (convention audit) or TodoRaider (content scan)?
- Does `NEW_TICKET` stay as catch-all or do we deprecate it once the typed versions are established?
- Scanner ownership: TodoRaider upgrade or a new dedicated script?
- When does scan run: on demand, session start, pre-commit hook?
