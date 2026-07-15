# What A Session Actually Produces

**Date:** 2026-06-18
**Concept:** Complete catalog of artifact types a session emits, mapped across the two location families
**State:** ready-for-scribe

## Stream

I read both families end to end. There are two physically separate session trees and they do NOT produce the same artifacts. That is the first thing the SessionScrutinizer has to internalize: "session" is not one shape.

Type A lives under `.agents/sessions/`. These are archival handover packages, written at the END of a session by the `session-handover` skill. The canonical shape is tiny: `manifest.toml` (date, slug, goal, model, session_name, optional `[status]` block) plus `crumbs.md` (skinny handover with YAML frontmatter -- session/model/date/goal/state -- then Goal / Key Findings / Loose Ends / Hot Context sections). The fat tier adds `loaf.md`. Some packages add `plans/plan-<slug>.md`. The repo-knowledge-harvest package shows the upper bound: `repos/*.md`, `telemetry-dump.json`, COMBINED-ANALYSIS.md, FINAL-REPORT.md, ABSORPTION-INDEX.md. But there is real drift even here: `2026-06-16_dev-saga-v1-poc` uses `HANDOVER.md` instead of `crumbs.md`. So even Type A is not perfectly uniform. The floor is `manifest.toml` + one handover file.

Type B lives under `.sessions/` (no `.agents` prefix). This is a richer, LIVE workspace tree created at the START of a session. The flagship example is `master-gitworkflow-audit-and-git-snapshot-skill/`, which contains: `plans/` (`__RAW_<slug>.md` raw prompt capture + `<slug>-v001.md` processed plan with caveman summary), `meetings/` (council/orchestrator verdicts), `handovers/` (`session-handover-<date>--<slug>.md`), and `.knowledgeblob/` (8 working-memory blobs, currently flat). Other Type B dirs are looser: `auto-convention-visualiser/` is just `TODO.md` + `image.png`; `git-workflow-animation/` contains a whole nested git repo (`camera-sentinel/.git/...`); `resume-uninterrupted-skill/` is a single oddly-named markdown file at the dir root.

The single most important concrete finding: the session's own handover doc and `audit-workflow-v001.md` both spell the folder `meeting/` (singular). On disk it is `meetings/` (plural). The convention was written one way and created another way IN THE SAME SESSION. That is the canonical drift case and the reason SessionScrutinizer exists.

What SHOULD be in the current Type B session but isn't: no `manifest.toml` (Type B has no manifest convention at all), no `crumbs.md`/`loaf.md` (it uses `handovers/` instead), no formal `.tickets/open/dp-134_*.md` despite a `chore/dp-134-*` branch existing, `.knowledgeblob/` blobs are flat (the approved `{agent-type}-{three-words}/` subfolder convention is unenforced).

## Shape so far

- Type A (`.agents/sessions/`): `manifest.toml` + `crumbs.md` (floor); `loaf.md`, `plans/`, ad-hoc analysis files (ceiling). End-of-session, committed, archival.
- Type A drift exists: `HANDOVER.md` vs `crumbs.md`.
- Type B (`.sessions/`): `plans/` (`__RAW_` + `vNNN`), `meetings/`, `handovers/`, `.knowledgeblob/`. Start-of-session, live workspace. No manifest convention.
- Type B is far looser -- some dirs are a single file or a nested git repo.
- **Drift smoking gun:** convention docs say `meeting/`, disk says `meetings/`. Same session.
- Missing-but-expected this session: dp-134 ticket file, knowledgeblob subfolders, any manifest for Type B.

## Still unresolved

- Is `manifest.toml` ever expected in Type B, or is `handovers/` the substitute? No convention says.
- Is `HANDOVER.md` (dev-saga) a legacy name or a still-valid alias for `crumbs.md`?
- Should `image.png` / binary assets be a flagged artifact type, or ignored?
- Nested git repos inside `.sessions/` (camera-sentinel) -- artifact or accident? Scrutinizer should probably skip `.git/` entirely.
