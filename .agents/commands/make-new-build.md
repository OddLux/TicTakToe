---
version: 1.0.0
---

Orchestrate full release cycle.

## Steps

### 1. derive-version
Bump version in pyproject.toml. Determine bump type (patch / minor / major)
from the commits since the last tag, or from explicit user instruction.

### Gate check (between steps 1 and 2)

After step 1, read the bump type:

- **patch**, **minor**, or **major**: Spawn the `release-guardian` agent with the bump type, new version string, and previous version tag.
- If the bump is **major**, also spawn the `protocol-grandmaster` agent (`/grandmaster-audit`).

Wait for the verdicts:
- **BLOCK** or grandmaster **HOW-ABOUT-NO**: Halt the release. Print the blocking issues. Do NOT proceed to step 2. Revert the uncommitted version bump from step 1:
  ```bash
  git checkout -- pyproject.toml uv.lock
  ```
- **REVIEW**: Print the findings. Ask the user: "Proceed with release or fix first?" Wait for answer before continuing.
- **APPROVE** and grandmaster **PASS**: Proceed to step 2.

### 1.5. stamp-meta-version
After the gate check returns APPROVE, run:
```bash
uv run python scripts/deploy_statusline.py --update-meta-version
```
This stamps the new version from pyproject.toml into all `~/.claude*/harness-meta.json` files so the statusline footer (L10 `[dev-protocol:X.Y.Z]`) updates in all active instances without requiring a manual `/statusline` redeploy. Skip silently if the script errors (non-blocking for the release).

### 2. write-release-notes
Generate entries, update CHANGELOG.md [Unreleased] -> [X.Y.Z].

### 3. update-readme
Sync README features and badges with the new version.

### 4. update-docs
Sync developer guides if needed.

### 5. commit-changes
Stage and commit with release message. Tag the release.
