---
name: setup-hooks
description: >
  Interactive hooks setup walkthrough. Detects the project environment, grills
  the user on their CI/CD platform and preferences, and executes each tier:
  local git hooks, pre-commit (optional), and CI/CD enforcement. Use when
  setting up a new project, onboarding a contributor, or auditing hook coverage.
version: 1.0.0
status: experimental
runs: 0
last-run: never
upgrade-conditions:
  - "hooks API changes"
  - "new CI/CD platforms added to support list"
---

# Setup Hooks (Interactive)

Walk the user through three tiers of changelog-gate enforcement. Detect
environment first, then grill the user on each decision, then execute.

---

## Phase 1: Detect (run silently, report once)

Run all of these before saying anything:

```bash
git remote -v
git config core.hooksPath
ls hooks/ 2>/dev/null || echo "(no hooks/ dir)"
test -f CHANGELOG.md && echo "CHANGELOG.md present" || echo "CHANGELOG.md missing"
test -f scripts/install_hooks.py && echo "install_hooks.py present" || echo "missing"
test -f .pre-commit-config.yaml && echo "pre-commit config found" || echo "(no pre-commit)"
```

Parse results and build a one-paragraph status summary:

- Remote platform: GitHub / GitLab / Azure DevOps / none
- Tier 1 (local hooks): active / installed-but-not-activated / missing
- Tier 2 (pre-commit): configured / not present
- Tier 3 (CI/CD): workflow found / missing

Report the summary to the user. Example:
> "Found a GitHub remote. Local hooks are installed but not activated
> (`install_hooks.py` exists, `core.hooksPath` not set). No CI/CD workflow.
> Pre-commit not configured. Want to set up all three tiers, or pick specific ones?"

---

## Phase 2: Scope Gate

Ask: **"Which tiers do you want to set up?"**

Options:
- All three (recommended)
- Tier 1 only (local hooks)
- Tier 3 only (CI/CD, team-wide enforcement)
- Custom - user picks

Do not proceed past this gate without a clear answer.

---

## Phase 3: Tier 1 - Local Git Hooks

**Skip if** `core.hooksPath = hooks` already confirmed in Phase 1.

Ask: "Should I activate local hooks now? (`uv run python scripts/install_hooks.py`)"

If yes:
```bash
uv run python scripts/install_hooks.py
git config core.hooksPath   # verify
```

If `hooks/commit-msg` is missing (project not initialized with dev-protocol):
- Explain: "The hook file is missing. This project may not have been initialized
  with `dev-protocol init`. Either run that, or I can create `hooks/commit-msg`
  directly."
- Ask which they prefer, then act.

**Verify:**
```bash
git config core.hooksPath
# Expected: hooks
```

Confirm out loud: "Tier 1 active. Direct `git commit` calls are now gated."

---

## Phase 4: Tier 2 - Pre-commit Framework (Optional)

Ask: "Do you use `pre-commit` in this project?"

If no or unsure: skip, note it in the summary.

If yes and `.pre-commit-config.yaml` exists:
- Show the current config.
- Explain: "Pre-commit hooks run at a different stage than `commit-msg` hooks.
  The changelog gate is best enforced by the `commit-msg` hook (Tier 1). If you
  want a pre-commit hook that runs linting or formatting before the gate, that's
  additive - not a replacement."
- Ask if they want anything added to `.pre-commit-config.yaml`.

If yes and no config exists:
- Ask: "Want me to scaffold a minimal `.pre-commit-config.yaml` with ruff + the
  standard file checks?"
- If yes, write it:

```yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.6.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-toml

  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.9.0
    hooks:
      - id: ruff
        args: [--fix]
      - id: ruff-format
```

Then: `uv run pre-commit install`

---

## Phase 5: Tier 3 - CI/CD Enforcement

**Ask: "Do you want the changelog gate enforced in CI as well?"**

This is the team-wide layer - catches pushes from machines where local hooks
were never activated. Strongly recommended for shared repos.

Sub-ask based on detected remote:

### GitHub Actions

Ask: "I see a GitHub remote. Should I create `.github/workflows/changelog-gate.yml`?"

If yes, create it:

```yaml
name: Changelog gate

on:
  push:
    branches: ["**"]
  pull_request:
    branches: ["**"]

jobs:
  changelog-gate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 2

      - name: Check changelog for feature/bugfix/refactor commits
        run: |
          git log --format="%s" HEAD^..HEAD | while IFS= read -r msg; do
            if echo "$msg" | grep -qE '^(feature|bugfix|refactor)(!)?(\([^)]+\))?:'; then
              if ! git diff --name-only HEAD^ HEAD | grep -q "CHANGELOG.md"; then
                echo ""
                echo "  Changelog gate: commit requires CHANGELOG.md update."
                echo "  Commit: $msg"
                echo "  Add an entry under [Unreleased] and push again."
                echo ""
                exit 1
              fi
            fi
          done
```

### GitLab CI

Ask: "I see a GitLab remote. Should I add a `changelog-gate` job to `.gitlab-ci.yml`?"

If yes and no `.gitlab-ci.yml` exists, create it:

```yaml
changelog-gate:
  stage: test
  script:
    - |
      git log --format="%s" HEAD^..HEAD | while IFS= read -r msg; do
        if echo "$msg" | grep -qE '^(feature|bugfix|refactor)(!)?(\([^)]+\))?:'; then
          if ! git diff --name-only HEAD^ HEAD | grep -q "CHANGELOG.md"; then
            echo "Changelog gate: $msg requires CHANGELOG.md update"
            exit 1
          fi
        fi
      done
  rules:
    - if: $CI_PIPELINE_SOURCE == "push"
```

If `.gitlab-ci.yml` already exists, show the job block and ask where to add it.

### No remote / other platform

Note: "No GitHub/GitLab remote detected. CI/CD setup is manual - see the
playbook (`.agents/playbooks/git-hooks-setup.md`) for the pattern to adapt."

**Verify (GitHub):**
- Ask: "Want me to do a dry-run commit to confirm the hook fires correctly?"
- If yes: stage a test file, attempt a `feature(test): ...` commit without
  touching CHANGELOG.md, confirm the hook blocks it, then clean up.

---

## Phase 6: Summary

Print a tier status table:

```
Tier 1 - Local hooks:    [active | not activated | skipped]
Tier 2 - Pre-commit:     [configured | skipped | not applicable]
Tier 3 - CI/CD:          [workflow created | already present | skipped]
```

If any tier was skipped, note how to come back:
- Tier 1 skipped: "Run `uv run python scripts/install_hooks.py` when ready."
- Tier 3 skipped: "Re-run `/setup-hooks` and choose Tier 3 only, or see `.agents/playbooks/git-hooks-setup.md`."

Offer to run `commit-changes` if any new files were created.
