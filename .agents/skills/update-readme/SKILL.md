---
name: update-readme
description: >
  Scans the codebase and updates README.md to reflect current features,
  version badge, and links. Use after adding features, changing CLI
  commands, or bumping the version.
version: 1.0.0
status: experimental
runs: 0
last-run: never
upgrade-conditions:
  - "README.md section schema changes"
---

# Update README

Ensures README.md accurately reflects the current state of the project.

## Instructions

### 1. Scan Features

- Read the project's entry points from `pyproject.toml` `[project.scripts]`
  or `[project.gui-scripts]`.
- Read the main CLI module and any command submodules.
- Identify active commands, subcommands, and their docstrings or help text.
- Note any new features, removed commands, or changed behavior since the
  last README update.

### 2. Update Features Section

- Open `README.md`.
- Locate the "Features" section (or equivalent).
- Update the list to match implemented functionality.
- Remove references to features that no longer exist.
- Add new features with a brief, user-facing description.

### 3. Update Version Badge

Read the current version:

```bash
uv version --short
```

Update the version badge at the top of `README.md` to match. Common formats:

```markdown
![Version](https://img.shields.io/badge/version-1.3.0-blue)
```

### 4. Verify Links

- Check all relative links in `README.md` (e.g., `[Docs](docs/...)`)
  to confirm the target files exist.
- Flag any broken links.

### 5. Verify Consistency

- Confirm the version in the badge matches `pyproject.toml`.
- Confirm feature descriptions match actual CLI help output.
- If installation instructions reference specific dependencies, confirm
  they match `pyproject.toml`.

### 6. Verify Dev Quickstart Exists

Every README must have a short "clone and test" block near the top of Quick
Start (or equivalent entry section). It must cover three things:

1. **Setup** -- the command to install deps (e.g. `uv sync --group dev`).
2. **Test** -- the command to run the test suite (e.g. `uv run pytest`).
3. **Lint** -- the command to run the linter (e.g. `uv run ruff check .`).

If any of the three are missing, add them. Derive the correct commands from
`pyproject.toml` (`[dependency-groups]`, `[tool.pytest.ini_options]`,
`[tool.ruff]`). This block is non-negotiable -- a developer opening a terminal
for the first time must be able to go from clone to green tests without reading
anything else.
