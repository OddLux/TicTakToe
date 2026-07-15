# Convention Gaps Found

**Date:** 2026-06-18
**Concept:** Conventions invented this session that have no formal backing yet, and the FAIL-vs-WARN call for each
**State:** ready-for-scribe

## Stream

The 2026-06-18 session invented a pile of structure on the fly. Almost none of it is in AGENTS.md. The SessionScrutinizer has to know what is real-and-enforceable versus emergent-and-soft, otherwise it will fire FAIL on things that were never formal rules. Here is every gap I found, with my honest call.

**Gap 1 -- `.sessions/` itself is undocumented.** AGENTS.md Workspace section 5 only describes `.agents/sessions/` (Type A). Grep for `.sessions` in AGENTS.md returns nothing. So the entire Type B tree -- `plans/`, `meetings/`, `handovers/`, `.knowledgeblob/` -- is unbacked. Anything checked inside `.sessions/` is checking against a convention that lives only in session plan docs. **Call: WARN.** You cannot FAIL a folder for violating a rule that isn't written down anywhere authoritative.

**Gap 2 -- knowledgeblob subfolder naming approved-but-unenforced.** MasterOrchestrator APPROVED `{agent-type}-{three-words}/` subfolders. But every existing blob (8 in the session, 3 in concepto-bot) is flat. So the convention is ratified in a verdict doc but implemented nowhere. **Call: WARN.** Approved != shipped. Flagging flat blobs as FAIL would fail 100% of existing reality. WARN with a "convention approved, not yet migrated" note.

**Gap 3 -- `meeting/` vs `meetings/` inconsistency.** This is the worst one because it is internal contradiction in one session. The handover doc and `audit-workflow-v001.md` both write `meeting/` (singular). The orchestrator vet verdict also says `meeting/`. Disk reality: `meetings/` (plural). The docs and the filesystem disagree. **Call: WARN now, FAIL once a canonical spelling is locked.** Right now there is no single source of truth saying which is correct, so you can only flag the inconsistency, not declare a winner. The scrutinizer's value here is exactly surfacing "your docs say X, your disk says Y."

**Gap 4 -- 🗿 postmortem marker convention.** The approved rule: `postmortem-{slug}.md` MUST open with a Caveman Ultra summary block. The handover's section 10 demonstrates it (`## POSTMORTEM 🗿 [caveman: ultra]`). This ties into the existing `session-completion-marker.md` rule (`🗿 [jobsdone: done]`), which IS formal. So the 🗿 marker family is half-formal: the jobsdone marker is a real rule; the postmortem-caveman-block is approved-but-emergent. **Call: jobsdone marker = FAIL-eligible (real rule); postmortem block = WARN (emergent).**

The throughline: a convention's enforceability tier is set by WHERE it is written, not how good it sounds. Written in AGENTS.md or `.agents/rules/` = established = FAIL on breakage. Written only in a session verdict/plan/handover = emerging = WARN. That mapping is the scrutinizer's whole judgment model for this session's artifacts.

## Shape so far

- `.sessions/` tree: undocumented in AGENTS.md -> WARN.
- knowledgeblob `{agent-type}-{three-words}/`: approved in verdict, zero adoption -> WARN.
- `meeting/` vs `meetings/`: docs say singular, disk says plural -> WARN (flag the contradiction), FAIL only after a canonical spelling lands.
- 🗿 jobsdone marker: real rule (`session-completion-marker.md`) -> FAIL-eligible.
- 🗿 postmortem caveman block: approved-emergent -> WARN.
- **Rule:** enforceability = location of the convention. AGENTS.md/.agents/rules = FAIL. Session-internal doc = WARN.

## Still unresolved

- Who promotes an emergent convention to formal? Until that happens every Type B check is stuck at WARN.
- For `meeting/` vs `meetings/` -- which spelling should the scrutinizer eventually canonicalize to? Plural matches `plans/`, `handovers/`; singular matches the written verdict.
- Should the scrutinizer auto-file a `#TODO:NEW_CONVENTION` (the in-flight tag system) when it finds an approved-but-unbacked convention?
