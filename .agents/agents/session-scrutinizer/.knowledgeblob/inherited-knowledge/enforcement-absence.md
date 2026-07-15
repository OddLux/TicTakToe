# Enforcement Absence

**Date:** 2026-06-18
**Concept:** Conventions without enforcement are suggestions; what the scrutinizer + validator fix; the FAIL/WARN threshold
**State:** ready-for-scribe

## Stream

The defining condition of session artifacts in this repo right now is that NOTHING checks them. There is no validator, no hook, no schema gate. Conventions are written into plan docs, verdicts, and handovers, and then everyone hopes they get followed. They don't.

The proof is in this very session. The `meeting/` vs `meetings/` split happened because three documents (the handover, `audit-workflow-v001.md`, the orchestrator verdict) all wrote the folder as `meeting/` -- and then the folder got created as `meetings/`. No tool caught the divergence. The author of the docs and the creator of the folder were the same agent, in the same session, and they still drifted. That is the whole argument: a convention a single agent can't even keep consistent with itself within one session has zero chance of surviving across sessions and agents without a check. ProjectGrandmaster made the structural version of this point about the TODO taxonomy -- "it designs the syntax for a discipline this project has already demonstrated it does not have." Same disease. 4 of 33 TODO files use the inline-tag convention, and those 4 disagree with each other. 12% adoption, already corrupted. Conventions without enforcement decay toward noise.

This is exactly the void the SessionScrutinizer + a `session_validator.py` are meant to fill. The scrutinizer is the judgment layer: read a session folder, compare it to the known conventions (Type A schema, Type B emergent patterns, naming regex), and report what conforms and what drifted. The validator script is the cheap mechanical layer: regex the filenames, check required files exist, confirm `manifest.toml` parses, confirm crumbs has its frontmatter. Together they convert "suggestions nobody checks" into "checks that run." That alone would have caught `meetings/` vs `meeting/` instantly.

The threshold question -- when is a check FAIL versus WARN -- is the heart of the design, and the answer the evidence points to is: **FAIL when the convention is established and broken; WARN when the convention is emerging and not yet formal.** "Established" has a concrete test: is it written in AGENTS.md or `.agents/rules/`? If yes, it's load-bearing and breaking it is a real defect -> FAIL. If the convention lives only inside session docs / verdicts / handovers (everything `.sessions/`-related right now), it's emergent -> WARN. This keeps the scrutinizer from screaming FAIL at a reality where the rule was never authoritative -- which would be both wrong and quickly ignored (a validator that cries wolf gets muted). It also gives a clean promotion path: when an emergent convention gets written into AGENTS.md, its checks graduate from WARN to FAIL automatically by the same rule.

Concretely against this session: Type A schema violations (missing manifest, malformed crumbs frontmatter) = FAIL, because AGENTS.md backs that schema. `.sessions/` structure issues, flat knowledgeblobs, `meetings/`-vs-`meeting/` = WARN, because none of it is formal yet. The 🗿 jobsdone marker is a real rule -> its absence on a completed session = FAIL.

## Shape so far

- Zero enforcement exists for session artifacts today -- no validator, no hook, no gate.
- Result: drift, proven by `meetings/`-vs-`meeting/` happening within a single session, and 12% corrupted TODO-tag adoption.
- Unenforced conventions are just suggestions and decay toward noise (Grandmaster's thesis).
- SessionScrutinizer = judgment layer (compare folder to conventions, report). `session_validator.py` = mechanical layer (regex/exists/parse checks). Together they make the implicit explicit.
- **Threshold answer:** FAIL = established (in AGENTS.md / `.agents/rules/`) and broken. WARN = emerging, not yet formal.
- Promotion path: WARN -> FAIL automatically when a convention is written into AGENTS.md.

## Still unresolved

- Where does the scrutinizer get the canonical "established conventions" list -- parse AGENTS.md live, or carry a baked-in copy that can itself drift?
- Should a FAIL ever block (commit hook), or stay report-only? Current project culture (agent-self-ticketing never blocks) argues report-only.
- For genuinely contradictory conventions (`meeting/` vs `meetings/` with no winner), is the right output a WARN, or a distinct "CONFLICT" tier that demands a human ruling before either can become FAIL?
