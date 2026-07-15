---
name: update-docs
description: >
  Updates developer documentation and project guides after code changes.
  Use after modifying dependencies, test setup, build process, or
  deployment configuration. Keeps install and usage instructions current.
version: 1.0.0
status: experimental
runs: 0
last-run: never
upgrade-conditions:
  - "docs/ directory structure changes"
---

# Update Docs

Maintains developer documentation and project guides so they stay in sync
with the codebase.

## Instructions

### 1. Analyze Changes

```bash
git diff --name-only HEAD~1..HEAD
```

Or compare against a broader range if multiple commits are involved.

Identify what changed:
- `pyproject.toml` dependencies -> installation instructions may be stale
- `tests/` structure or config -> testing instructions may be stale
- Build/run entry points -> usage instructions may be stale
- CI/CD config -> deployment docs may be stale

### 2. Update Installation Instructions

If dependencies changed in `pyproject.toml`:
- Update the "Installation" section in `README.md` or `docs/developer_guide.md`.
- Confirm the documented install command still works (e.g., `uv sync`).
- If new system-level dependencies were added, document them.

### 3. Update Testing Instructions

If test configuration or structure changed:
- Update the "Testing" section with current commands.
- Confirm documented test commands are correct (e.g., `uv run pytest`).
- If new test fixtures or setup steps are required, document them.

### 4. Update Usage / Deployment

If build artifacts, entry points, or run methods changed:
- Update the "Usage" section in README or relevant guide.
- Confirm documented commands match actual behavior.

### 5. Verify

- Confirm all documented commands are runnable.
- Confirm file paths referenced in docs exist.
- Flag any sections that reference removed functionality.
