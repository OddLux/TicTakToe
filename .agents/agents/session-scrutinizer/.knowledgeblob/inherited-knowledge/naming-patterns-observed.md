# Naming Patterns Observed

**Date:** 2026-06-18
**Concept:** Concrete regex for every session naming pattern seen in the wild
**State:** ready-for-scribe

## Stream

These are derived from observed reality, not from a spec (there mostly isn't one). The SessionScrutinizer validates against these, so precision matters. Where I saw conflicting evidence I say so.

**Date stamp.** Always ISO 8601 `YYYY-MM-DD`. Seen in Type A dir names (`2026-06-18_raw-photo-research`), crumbs frontmatter, manifest `date`, handover filenames. Regex: `\d{4}-\d{2}-\d{2}`. No other date format appears anywhere.

**Type A session dir.** `{date}_{slug}` with an underscore joining date and slug, slug in kebab-case. Examples: `2026-06-16_council-coach-jiranitor`, `2026-06-18_raw-photo-research`. AGENTS.md calls the slug `<3-word>` but observed slugs run 2-4 words. Regex: `^\d{4}-\d{2}-\d{2}_[a-z0-9]+(-[a-z0-9]+){1,4}$`. Note: the date-slug join is `_` (underscore) even though everything inside the slug is `-` (hyphen). That mixed separator is intentional and consistent across Type A.

**Type B session dir.** Pure kebab-case slug, NO date prefix. Examples: `master-gitworkflow-audit-and-git-snapshot-skill`, `auto-convention-visualiser`, `git-workflow-animation`. Word count is wide (1 to 7+ words). Regex: `^[a-z0-9]+(-[a-z0-9]+)*$`. This is a real divergence from Type A -- Type B drops the date entirely.

**Handover filename (Type B).** Double-dash separator between date and slug: `session-handover-{date}--{slug}.md`. Observed: `session-handover-2026-06-18--todo-sanity-hub-convention-draft.md`. The `--` is deliberate (single `-` would be ambiguous against the date's own hyphens and the kebab slug). Regex: `^session-handover-\d{4}-\d{2}-\d{2}--[a-z0-9]+(-[a-z0-9]+)*\.md$`.

**`__RAW_` prefix (plans).** Double-underscore lead, then `RAW`, then single underscore, then slug. Observed: `__RAW_audit-workflow.md`. Content header marks it UNPROCESSED / DO NOT EDIT. Regex: `^__RAW_[a-z0-9]+(-[a-z0-9]+)*\.md$`. (An open question in the plan doc itself asks whether RAW should be double or single underscore -- observed reality is double.)

**Plan version suffix.** `{slug}-vNNN.md`, zero-padded to **3 digits**. Observed: `audit-workflow-v001.md`. Not `v1`, not `v01`. Regex: `-v\d{3}\.md$`. Plan doc references v001/v002 progression.

**Knowledgeblob subfolder.** `{agent-type}-{word1}-{word2}-{word3}` -- agent type in kebab-case followed by exactly **3** random words. Example from spec: `concepto-bot-river-amber-shield`. The agent-type portion can itself be multi-token kebab (`concepto-bot` = 2 tokens), so the regex can't naively count total hyphens; the THREE-WORD slug is the trailing segment. Minimum total segments: agent-type (>=1 token) + 3 slug words. Regex (loose): `^[a-z0-9-]+-[a-z]+-[a-z]+-[a-z]+$` with the last 3 hyphen groups being the three-words. NOTE: zero adoption so far -- all blobs are currently flat files, so this pattern validates nothing real yet (WARN, not FAIL).

**General slug rule.** Always lowercase, hyphens only, no underscores inside the slug, no camelCase. Underscores appear ONLY as structural separators (`{date}_{slug}`, `__RAW_`), never inside a slug itself.

## Shape so far

- Date: `\d{4}-\d{2}-\d{2}` everywhere, no exceptions.
- Type A dir: `{date}_{kebab-slug}` (underscore join, hyphen slug, 2-4 words observed).
- Type B dir: bare `{kebab-slug}`, no date, 1-7 words.
- Handover: `session-handover-{date}--{slug}.md` (double-dash).
- `__RAW_` plan: double-underscore prefix, `__RAW_{slug}.md`.
- Plan version: `vNNN` zero-padded **3 digits**.
- Knowledgeblob subfolder: `{agent-type}-{w1}-{w2}-{w3}`, 3 trailing words; currently unadopted.
- Slug = lowercase-kebab; underscore is structural-only.

## Still unresolved

- AGENTS.md says Type A slug is `<3-word>` but reality is 2-4 words. Validate against observed (2-4) or documented (3)? I lean observed, WARN on documented mismatch.
- The three-words slug's agent-type prefix length is variable -- a strict regex needs the agent name known in advance to split cleanly. Scrutinizer may need the agent registry to validate this precisely.
- Is `--v002` ever date-suffixed instead (`{slug}-2026-06-18.md`)? Plan doc lists it as an open question. Only `vNNN` observed so far.
