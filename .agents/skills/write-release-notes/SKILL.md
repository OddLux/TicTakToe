---
name: write-release-notes
description: >
  Generates release notes and updates CHANGELOG.md from git history.
  Use when preparing a release, writing a changelog entry, or when the
  user asks to document what changed since the last version.
version: 1.0.0
status: experimental
runs: 0
last-run: never
upgrade-conditions:
  - "CHANGELOG.md format changes"
  - "new commit types added"
---

# Write Release Notes

Generates human-readable release notes from git history and updates
CHANGELOG.md using Keep a Changelog format.

## Instructions

### 1. Gather Context

```bash
# Current version
uv version --short

# Previous tag
git describe --tags --abbrev=0

# If no tags exist, use the root commit
git rev-list --max-parents=0 HEAD
```

```bash
# Commit log since last tag
git log <last_tag>..HEAD --pretty=format:"%s"

# File change summary
git diff --stat <last_tag>..HEAD
```

### 2. Analyze and Categorize

Map each commit to a changelog section using its type prefix:

| Commit Type | Changelog Section |
|-------------|-------------------|
| `feature` | **Added** |
| `bugfix` | **Fixed** |
| `refactor` | **Changed** |
| `style` | **Changed** |
| `docs` (user-facing) | **Changed** |
| `test` | Omit (unless notable) |
| `chore` | Omit (unless notable) |

Use `git diff --stat` to gauge the scope of changes:
- Large diffs in `src/` suggest significant features worth highlighting.
- Changes only in `docs/` -> documentation update.
- Changes in `pyproject.toml` deps -> note dependency updates.

### 3. Write the Entry

**Style rules:**
- Write a human-readable summary. Do not just dump the git log.
- Each bullet should explain what changed and why it matters.
- Reference affected files or modules when it adds clarity.

**Good:** "Added generic file scanning with configurable ignore patterns (`src/scanner.py`)"
**Bad:** "feature: scanner"

**Format:**

```markdown
## [1.3.0] - 2026-02-11

### Added
- Generic file scanning with configurable ignore patterns
- CLI export command for batch processing

### Fixed
- Empty directory handling in recursive scan
- Off-by-one error in frame sequence validation

### Changed
- Refactored config loading to use dataclasses
- Updated installation docs for uv workflow
```

- Version in brackets: `[1.3.0]`
- Date in ISO 8601: `YYYY-MM-DD`
- Version must match `uv version --short`

### 4. Update CHANGELOG.md

- Read the existing `CHANGELOG.md`.
- Insert the new entry **below the header and any `[Unreleased]` section**.
- If an `[Unreleased]` section exists with content, move its items into
  the new versioned entry as appropriate, then reset `[Unreleased]` to empty.

**CHANGELOG.md header template** (if creating from scratch):

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.3.0] - 2026-02-11
...
```

### 5. Verify

- Confirm the version in the entry matches `pyproject.toml`.
- Confirm the file is valid Markdown.
- Confirm dates use ISO 8601 format.
