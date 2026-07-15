---
name: caveman-commit
description: >
  Ultra-compressed commit message generator. Terse, exact, why over what.
  Full-word commit types (feature/bugfix, not feat/fix). Subject 100-char cap.
  Use when user says "write a commit", "commit message", "generate commit",
  or invokes /caveman-commit.
version: 1.0.0
status: experimental
runs: 0
last-run: never
upgrade-conditions:
  - "commit type taxonomy changes"
  - "subject line length limit changes"
---

Write commit messages terse and exact. Why over what. No fluff.

## Rules

**Subject line:**
- `<type>(<scope>): <imperative summary>` - `<scope>` optional
- Types: `feature`, `bugfix`, `docs`, `style`, `refactor`, `test`, `chore`
- Imperative mood: "add", "fix", "remove" - not "added", "adds", "adding"
- Soft target ~70 chars, hard cap 100
- No trailing period
- `feature!:` or `BREAKING CHANGE:` footer for breaking changes

**Body (only if needed):**
- Skip entirely when subject is self-explanatory
- Add body only for: non-obvious *why*, breaking changes, migration notes, linked issues
- Wrap at 100 chars
- Bullets `-` not `*`
- Reference issues/PRs at end: `Closes #42`, `Refs #17`

**What NEVER goes in:**
- "This commit does X", "I", "we", "now", "currently" - the diff says what
- "As requested by..." - use Co-authored-by trailer
- "Generated with Claude Code" or any AI attribution
- Restating the file name when scope already says it

## Examples

Diff: new endpoint for user profile with non-obvious why
- bad: "feature: add a new endpoint to get user profile information from the database"
- good:
  ```
  feature(api): add GET /users/:id/profile

  Mobile client needs profile data without the full user payload
  to reduce LTE bandwidth on cold-launch screens.

  Closes #128
  ```

Diff: breaking API change
- good:
  ```
  feature(api)!: rename /v1/orders to /v1/checkout

  BREAKING CHANGE: clients on /v1/orders must migrate to /v1/checkout
  before 2026-06-01. Old route returns 410 after that date.
  ```

Diff: simple bug fix, no body needed
- good: `bugfix(auth): handle missing token expiry field`

## Auto-Clarity

Always include body for: breaking changes, security fixes, data migrations, reverts.
Never compress these to subject-only - future debuggers need the context.

## Boundaries

Generates the commit message only. Does not run `git commit`, does not stage files.
Output as a code block ready to paste or use with `git commit -m`.
"stop caveman-commit" or "normal mode": revert to verbose commit style.
