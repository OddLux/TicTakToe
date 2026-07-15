---
name: create-session
description: >
  Scaffolds a Type B workspace session at .sessions/{slug}/. Accepts slug as arg
  or prompts interactively. Validates slug (kebab-case, 2-6 words, no underscores,
  no uppercase). Creates canonical directory tree (plans/, meetings/, handovers/,
  .knowledgeblob/), writes manifest.toml and README.md stubs, optionally captures
  a raw prompt blob to plans/__RAW_{topic}.md, prints a creation tree with absolute
  paths, and offers to run /set-goal. Idempotent: warns and aborts if slug already
  exists, never overwrites.
  Trigger: "create session", "new session", "start session", "/create-session",
  "/create-session {slug}".
invocation: agent
version: 1.0.0
status: experimental
runs: 0
last-run: never
upgrade-conditions:
  - ".sessions/ directory structure changes"
  - "manifest.toml schema adds required fields"
  - "Type B session naming conventions change"
  - "meetings/ canonical folder name changes"
---

# create-session

Scaffolds a **Type B workspace session** at `.sessions/{slug}/`. This is the
canonical entry point for starting a long-running working session with a persistent
artifact workspace.

---

## When to invoke

- User says "start a new session", "create session", "new session", "/create-session"
- Beginning of a planned multi-session effort that needs a persistent workspace
- When a raw prompt or brief needs to be captured alongside a session scaffold

---

## Step 0: Resolve slug

**If slug provided as arg** (e.g. `/create-session my-feature-work`):
Use it directly. Skip the interactive prompt.

**If no arg provided:**
Ask the user: `Session slug (kebab-case, 2-6 words, e.g. refactor-auth-flow):`
Accept their input. Strip leading/trailing whitespace.

---

## Step 1: Validate slug

Pattern: `^[a-z][a-z0-9]*(-[a-z0-9]+){1,5}$`

Rules enforced:
- Lowercase letters and digits only (hyphens as separators)
- Must start with a lowercase letter (not a digit, not a hyphen)
- 2 to 6 hyphen-delimited words (1 hyphen minimum, 5 maximum)
- No underscores, no uppercase, no consecutive hyphens, no trailing hyphen

Word count = number of hyphens + 1.

**On failure:** Print which rule was violated, then re-prompt (interactive mode)
or abort with a clear error (arg mode). Do not proceed with an invalid slug.

Example violations and messages:
- `my_session` -- contains underscore; use hyphens only
- `MySlug` -- uppercase not allowed; use all lowercase
- `a` -- one word; slug must have 2-6 words
- `a-b-c-d-e-f-g` -- 7 words; slug must have 2-6 words
- `123-bad` -- starts with digit; slug must start with a letter

---

## Step 2: Idempotency check

Check if `.sessions/{slug}/` already exists.

If it exists, print a presence table and abort:
```
[create-session] WARN: .sessions/{slug}/ already exists.

  plans/            {present | absent}
  meetings/         {present | absent}
  handovers/        {present | absent}
  .knowledgeblob/   {present | absent}
  manifest.toml     {present | absent}
  README.md         {present | absent}

Aborting. Use an existing session or choose a different slug.
```

Never overwrite or merge into an existing session.

---

## Step 3: Determine repo root

Find the repository root by walking up from the current directory until
`pyproject.toml` or `.git` is found. The `.sessions/` directory lives at
the repo root.

---

## Step 4: Create directory tree

Create the following structure (all absolute paths in output):
```
{repo-root}/.sessions/{slug}/
  plans/
  meetings/
  handovers/
  .knowledgeblob/
  manifest.toml     (written in Step 5)
  README.md         (written in Step 6)
```

Create all four subdirectories before writing files.

---

## Step 5: Write manifest.toml

Derive values:
- `date`: today's date as YYYY-MM-DD
- `slug`: validated slug from Step 1
- `goal`: convert slug to title case (replace hyphens with spaces, capitalize each word)
  Example: `refactor-auth-flow` -> `Refactor Auth Flow`
- `model`: current model ID if accessible (check environment or session metadata),
  fallback to `"unknown"` -- never leave empty
- `created`: ISO 8601 timestamp at moment of creation (YYYY-MM-DDTHH:MM:SS)

```toml
[session]
date = "YYYY-MM-DD"
slug = "{slug}"
goal = "{Title Cased Goal}"
model = "{model-id}"
type = "workspace"
status = "active"
created = "YYYY-MM-DDTHH:MM:SS"
```

---

## Step 6: Write README.md

```markdown
# {Title Cased Goal}

Session: `{slug}`
Created: YYYY-MM-DD
Status: active

## Goal

<!-- One-line description of this session's purpose. Edit this. -->

## Structure

| Directory | Purpose |
|-----------|---------|
| `plans/` | Raw prompt captures and processed plans |
| `meetings/` | Meeting notes and postmortems |
| `handovers/` | Session handover files |
| `.knowledgeblob/` | Persistent knowledge blobs |

## Conventions

- Raw prompts: `plans/__RAW_{topic}.md` -- never edited
- Processed plans: `plans/{topic}-v001.md` -- caveman summary at top
- Meeting notes: `meetings/meeting-notes-{slug}.md`
- Postmortems: `meetings/postmortem-{slug}.md` -- 🗿 caveman summary REQUIRED at top
- Handovers: `handovers/session-handover-{date}--{goal-slug}.md` (double dash)
```

---

## Step 7: Write raw prompt blob (optional)

Only if the user explicitly passes `--raw` followed by text, or marks content
for raw capture in the invocation.

Write to: `{repo-root}/.sessions/{slug}/plans/__RAW_{topic}.md`

Where `{topic}` is the first meaningful noun phrase from the raw text (2-3 words,
kebab-cased). Default to `prompt` if no clear topic can be extracted.

File format:
```markdown
<!-- RAW CAPTURE -- do not edit this file -->
<!-- topic: {topic} | captured: YYYY-MM-DDTHH:MM:SS -->

{raw text verbatim}
```

---

## Step 8: Print creation tree

Print with full absolute paths:
```
[create-session] Created {repo-root}/.sessions/{slug}/

  {repo-root}/.sessions/{slug}/manifest.toml        [workspace session, status: active]
  {repo-root}/.sessions/{slug}/README.md            [stub -- edit goal description]
  {repo-root}/.sessions/{slug}/plans/               [empty]
  {repo-root}/.sessions/{slug}/meetings/            [empty]
  {repo-root}/.sessions/{slug}/handovers/           [empty]
  {repo-root}/.sessions/{slug}/.knowledgeblob/      [empty]
  {repo-root}/.sessions/{slug}/plans/__RAW_{topic}.md  [raw prompt captured]
  ^-- only print this line if --raw was used
```

---

## Step 9: Offer /set-goal

Print:
```
Run /set-goal to register "{Title Cased Goal}" as the active session goal? [Y/n]
```

If user confirms (or presses Enter for default Y): invoke /set-goal with the
title-cased goal string as the argument.

If user declines: skip silently.

---

## Step 10: Print scrutinizer tip

Always print after creation:
```
Tip: run /scrutinize-session {slug} to audit this session's structure at any time.
```

---

## Error handling

| Condition | Behavior |
|-----------|----------|
| Slug fails regex | Print violated rule, re-prompt (interactive) or abort (arg) |
| Slug already exists | Print presence table, hard abort, no file changes |
| model ID not resolvable | Use "unknown" in manifest, do not fail |
| Raw blob has no clear topic | Default topic to "prompt" |
| File write failure | Report absolute path + OS error, do not partially create |
| Repo root not found | Abort with message "could not find repo root (no pyproject.toml)" |

---

## Notes on legacy sessions

Existing sessions under `.sessions/` that predate slug validation (e.g.
`master-gitworkflow-audit-and-git-snapshot-skill`) use longer, inconsistent
slugs that would fail the regex. This is expected. Do not retroactively
rename them. The validation only applies to new sessions created by this skill.
