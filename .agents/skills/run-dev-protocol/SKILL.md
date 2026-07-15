---
name: run-dev-protocol
description: >
  Run, smoke-test, build, lint, or verify dev-protocol. Use when asked to
  run the CLI, test a change, build a wheel, check the tool works, verify
  behavior after editing a command, or confirm a PR doesn't break the smoke
  suite. Covers: run, start, build, test, smoke, verify, check, wheel,
  lint, format.
invocation: agent
version: 1.0.0
status: experimental
runs: 0
last-run: never
upgrade-conditions:
  - "new test commands added"
  - "smoke.py path or behavior changes"
---

# run-dev-protocol

`dev-protocol` is a Python CLI (Click) installed as an editable package via
`uv`. It has two commands: `init` (stamp an agentic dev environment into a
target git repo) and `claude-sync` (re-mirror `.agents/` into `.claude/`).
All invocations use `uv run dev-protocol` from the repo root; no venv
activation needed.

## Prerequisites

- `uv` on PATH (already present in this repo's environment)
- Python 3.9+
- `git` on PATH (tests create temp git repos)

No extra packages needed beyond what `uv sync` installs from `pyproject.toml`.

## Run (agent path) - smoke script

The smoke script exercises all CLI code paths with real subprocess calls and
temp git repos. It is the primary verification harness.

```
uv run python .agents/skills/run-dev-protocol/smoke.py
```

Expected: `18 passed, 0 failed`. Any failure prints the expected vs. actual
output for that check.

**When to use smoke.py:**
- After editing any file in `src/dev_protocol/`
- After adding or removing vault files in `.agents/`
- After changing `pyproject.toml` entry points or hatchling includes
- Before cutting a release

## Run (direct invocation)

Invoke any command directly from the repo root:

```bash
# Help
uv run dev-protocol --help
uv run dev-protocol --version

# Init flags
uv run dev-protocol init --help
uv run dev-protocol claude-sync --help

# Dry-run in a consuming project (must be run from that project's root)
uv run dev-protocol init --dry-run
uv run dev-protocol init --claude --dry-run
uv run dev-protocol init --profile dneg --dry-run
uv run dev-protocol claude-sync --dry-run
```

Note: `init` and `claude-sync` both guard against being run from the
dev-protocol repo itself. To test against a real target, `cd` to a different
git repo and use `--project`:

```bash
cd /tmp/some-project && git init
uv run --project /path/to/dev-protocol dev-protocol init --dry-run
```

## Test suite

```bash
uv run pytest --tb=short -q
```

26 tests, ~1.4 s. Tests cover `init`, `claude-sync`, vault copy logic, and
template rendering. Always run before committing changes to `src/`.

## Build

Produces a pure-Python wheel. The build bundles `.agents/rules/`,
`.agents/skills/`, `.agents/commands/`, `.agents/agents/`, and
`.agents/profiles/` into the wheel as package data (see
`[tool.hatch.build.targets.wheel.force-include]` in `pyproject.toml`).

```bash
uv build --wheel
```

Output: `dist/dev_protocol-<version>-py3-none-any.whl`

**Verify vault files are bundled correctly:**

```bash
python -c "
import zipfile, sys
whl = sorted(__import__('pathlib').Path('dist').glob('*.whl'))[-1]
names = [n for n in zipfile.ZipFile(whl).namelist() if '_vault' in n]
print(f'{len(names)} vault entries in wheel')
"
```

Expect 30+ vault entries. Zero means the `force-include` paths didn't
resolve - check that `.agents/` subdirs exist.

## Lint and format

```bash
uv run ruff check src/ tests/
uv run ruff format --check src/ tests/
```

Both should exit 0 with no output (or "All checks passed!").
To auto-fix formatting: `uv run ruff format src/ tests/`

## Gotchas

- **`init` refuses to run inside dev-protocol's own repo.** `is_dev_protocol_repo()`
  detects `pyproject.toml[project].name == "dev-protocol"` and aborts. This is
  intentional. Use a temp git repo or `--dry-run` to test init logic.

- **Vault files must exist at build time.** `force-include` in `pyproject.toml`
  maps live `.agents/` dirs into the wheel. If `.agents/skills/` is empty or
  missing, the built wheel will ship without vault content and `dev-protocol init`
  will stamp nothing.

- **`uv run --project` needed from outside the repo.** When testing `init` from
  a temp dir, pass `--project /path/to/dev-protocol` so uv finds the editable
  install. Without it, uv looks for a pyproject.toml in the temp dir and fails.

- **Sync script does not delete.** `sync_agent_configs.py` copies
  `.agents/skills/` -> `.claude/skills/` additively. Files in `.claude/skills/`
  that have no counterpart in `.agents/skills/` (like this skill) are left
  untouched.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `uv run dev-protocol: command not found` | Run `uv sync` from repo root to reinstall editable entry point |
| `Error: Cannot initialize dev-protocol inside its own repository` | Expected guard - `cd` to a different git repo or use `--dry-run` |
| `Error: Not a git repository root` | Must be run from a directory containing `.git/` |
| `Error: No .agents/ directory found` (claude-sync) | Run `init` first to create `.agents/` |
| Wheel has 0 vault entries | Check `.agents/rules/`, `.agents/skills/`, etc. exist; re-run `uv build --wheel` |
| `pytest` `WinError 183` on `.pytest_cache` | Benign Windows cache-dir warning - tests still pass |
