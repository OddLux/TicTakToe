---
name: derive-version
description: >
  Bumps the project version in pyproject.toml using uv. Use when the user
  requests a version bump, release preparation, dev build increment, or
  asks about the current version.
version: 1.0.1
status: experimental
runs: 0
last-run: never
upgrade-conditions:
  - "semver bump rules change"
  - "uv version API changes"
---

# Derive Version

Calculates and applies version bumps using `uv version` with pyproject.toml
as the single source of truth.

## Key Principle

**One file, one command.** The version lives in `pyproject.toml` only.
Runtime code reads it via `importlib.metadata.version(__name__)`. Never
update `__init__.py`, `cli/main.py`, or any other file with a hardcoded
version string.

## Instructions

### 1. Read Current Version

```bash
uv version --short
```

This prints the current version from `pyproject.toml`.

### 2. Determine Intent

Ask the user: **"Is this a release or a dev build?"**

Default bump type is **patch**. Do not offer minor/major as options unless the
user explicitly requests one. If the context makes intent obvious (e.g., "bump
for release"), proceed with patch without asking.

**Hard gate - minor or major:** If the user requests a `minor` or `major` bump,
STOP and confirm before applying:
> *"This would bump to vX.Y.0 (minor) / vX.0.0 (major). Confirm to proceed?"*
> Do not run the bump command until the user explicitly confirms. The only
> pre-approved exception is an explicit migration session (e.g., user has
> stated "we're working on v2").

### 3. Apply the Bump

**Release builds:**

```bash
# Patch (default): 1.2.3 -> 1.2.4
uv version --bump patch

# Minor (requires confirmation): 1.2.3 -> 1.3.0
uv version --bump minor

# Major (requires confirmation): 1.2.3 -> 2.0.0
uv version --bump major
```

**Dev builds (intermediate, auto-committed):**

```bash
# First dev: 1.3.0 -> 1.3.1.dev1 (or current -> next with dev suffix)
uv version --bump dev

# Subsequent: 1.3.1.dev1 -> 1.3.1.dev2
uv version --bump dev
```

**Pre-release progression:**

```
1.3.0.dev1 -> 1.3.0.dev2    (uv version --bump dev)
1.3.0.dev5 -> 1.3.0rc1      (uv version --bump rc)
1.3.0rc1   -> 1.3.0rc2      (uv version --bump rc)
1.3.0rc2   -> 1.3.0          (uv version --bump stable)
```

All versions must be **PEP 440 compliant**: `X.Y.Z`, `X.Y.Z.devN`,
`X.Y.ZrcN`. No hyphens, no `v` prefix in the version string itself.

### 3b. Stamp dependent version constants

Some files bake the version as a constant for environments that cannot import
the package at runtime. After any bump, re-stamp them so they stay in lockstep
(a drift-gate test fails otherwise):

```bash
uv run python scripts/stamp_harness_version.py
```

This updates `HARNESS_VERSION` in `dotfiles/.claude/statusline.py` (the
statusline's `[dp-X.Y.Z]` ticker). Safe to run every bump - it is idempotent
and a no-op when already in sync.

### 4. Confirm

- Print the new version: `uv version --short`
- If this is a release, remind that the next steps are:
  write-release-notes -> update-readme -> commit-changes
- If this is a dev build, suggest an auto-commit:
  `chore: bump v{version}`

## What NOT to Do

- Do not edit `__init__.py` or any source file to set a version string.
- Do not use the `v` prefix in `pyproject.toml`. The `v` prefix is for
  git tags only.
- Do not use non-PEP-440 formats like `1.0.0-dev.build3`. The correct
  format is `1.0.0.dev3`.

## Runtime Version Access Pattern

Projects should use this in their `__init__.py`:

```python
try:
    from importlib.metadata import version as _get_version
    __version__ = _get_version(__name__)
except Exception:
    __version__ = "0.0.0-unknown"
```

This reads from the installed package metadata (which comes from
pyproject.toml). No second source of truth.
