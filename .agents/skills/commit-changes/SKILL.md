---
name: commit-changes
description: >
  Stages and commits changes using Conventional Commits with full-word types.
  Use when committing code, after completing a task, or when the user asks
  to commit, stage, or save changes to git.
---

# Commit Changes

Stages, analyzes, and commits changes using the project's commit conventions.

## Instructions

### 1. Stage Changes

- Run `git add .` or stage specific files if the user requests it.
- Run `git status` to confirm what will be committed.

### 2. Analyze the Diff

- Run `git diff --staged` to understand what changed.
- Identify the primary intent: new feature, bug fix, refactor, etc.

### 3. Generate Commit Message

Format: `type(scope): description`

**Types:**

| Type | Use |
|------|-----|
| `feature` | New feature or capability |
| `bugfix` | Bug fix |
| `docs` | Documentation only |
| `style` | Formatting, no functional change |
| `refactor` | Restructuring, no behavior change |
| `test` | Adding or updating tests |
| `chore` | Build, deps, CI, tooling, releases |

**Rules:**

- **Scope** is optional but encouraged. Use the module or area affected:
  `feature(cli): add export command`, `bugfix(scanner): handle empty directories`
- **Subject line (first line):** imperative mood, max **72 characters**, no trailing period.
  Write "add retry logic" not "added retry logic" or "adds retry logic".
  It must stand completely alone - a reader seeing only this line must understand
  what changed and why. No continuation phrases ("also...", "and..."), no pronouns
  that refer to body text, no fragments. Treat it as a changelog entry headline.
- **Body (optional):** Free-form multi-paragraph expansion. Separated from subject
  by a blank line. Use when the why, tradeoffs, or scope is non-obvious.
  Body lines wrap at 100 characters.
- **Breaking changes:** append `!` after type - `feature!: redesign config format` -
  or add a `BREAKING CHANGE:` footer for multi-line commits.

**Special patterns:**

- Release commits: `chore: release v1.3.0`
- Dev bump commits: `chore: bump v1.3.0.dev2`

### 4. Changelog Gate

If the commit type is `feature`, `bugfix`, or `refactor`:

- Check whether `CHANGELOG.md` has been modified and staged in this session
  (`git diff --staged --name-only | grep CHANGELOG.md`).
- If CHANGELOG.md is **not** in the staged files: **stop.** Do not commit.
  Say: "This is a `{type}` commit. Update the `[Unreleased]` section of
  CHANGELOG.md first, then re-run commit-changes."
- Only proceed to Step 5 once CHANGELOG.md has been staged.

`docs`, `chore`, `test`, `style` commits: skip this step entirely.

### 5. Confirm and Commit

- Present the proposed message to the user for approval.
- Run `git commit -m "message"`.

## Decision Tree

```
Is this a version bump only?
  -> Yes: use `chore: release v{version}` or `chore: bump v{version}`
  -> No: continue

Does the change add new behavior visible to users?
  -> Yes: `feature(scope): ...`
  -> No: continue

Does the change fix broken behavior?
  -> Yes: `bugfix(scope): ...`
  -> No: continue

Is it restructuring without behavior change?
  -> Yes: `refactor(scope): ...`
  -> No: use `docs`, `style`, `test`, or `chore` as appropriate
```
