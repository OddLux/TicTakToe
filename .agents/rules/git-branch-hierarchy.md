# Version 3.0.0

# Git Branch Hierarchy

Rules and conventions defining the **single-trunk** branch model. v3.0.0 collapses
the old `master` + `develop` two-tier model into ONE long-lived trunk (`master`),
removes `develop` and `release` branches entirely, adds the permanent meta branch
types (`branding/`, `council/`, `prototype/`), and makes worktree isolation
mandatory on first file edit. Type-prefixed naming, permanent retention of
conforming branches, and committer identity conventions carry over from v2.

> **One-time consolidation (2026-06-23).** A single recovery pass deleted all
> pre-convention / non-conforming branches (`develop`, `agent/*`, `subagent*`,
> `ticket/*`, `worktree-*`, and merged unnamed branches) to establish a fully
> compliant baseline. From that baseline forward, permanent retention (§4) is
> absolute: no conforming branch is ever deleted again.

---

## 1. Branch Roles

### master (the ONLY long-lived trunk)
- **Role:** Production ledger and integration trunk in one. Every qualifying
  `feature`/`bugfix` commit lands here; release tags (`vX.Y.Z`) live here.
- **There is no `develop` and no `release` branch.** Work branches merge
  directly into `master`. No intermediate integration tier.
- **Access Policy:** No direct commits for routine work - changes arrive via a
  worktree-isolated work branch merged into `master`. `release-guardian` owns the
  release-tagging pass.
- **Merge Gate:** `--no-ff` merge from a work branch (preserves the branch point
  in the visual history). CHANGELOG entry required in the merge.

### {feature,bugfix,chore,docs}/dp-NNN-{slug}  (short-lived work branches)
- **Role:** Isolated work workspace. One branch per ticket. **Always** checked
  out in a worktree (see §6 and git-worktree-hygiene.md §1).
- **Naming Pattern:** `{type}/dp-NNN-{kebab-summary}` where `{kebab-summary}` is
  a caveman-ultra description of the work, max 65 chars, total name <= 80 chars.
  Example: `feature/dp-085-add-multi-path-config-resolution`
- **Merged directly into `master`**, then the worktree DIRECTORY is removed.
  The branch REF is retained permanently (§4).

### branding/{slug}  (permanent meta type)
- **Role:** Long-lived scratchpad for content/marketing/brand material.
- **dp-NNN exempt.** Slug is a kebab description (`branding/ux-inaugural`).
- Any model may write. Permanent retention.

### council/{slug}  (permanent meta type)
- **Role:** Big council-meeting commits, kept on their own branch for visibility
  in the tree view (`council/inauguration-v2`).
- **dp-NNN exempt.** Permanent retention. Written during council sessions.

### prototype/{slug}  (permanent meta type)
- **Role:** Seeds for immature experiments that outgrew `prototypes/` but are not
  yet mature tools (`prototype/camera-sentinel-the-next-step`).
- **dp-NNN exempt.** Permanent retention. The tracked `prototypes/` folder is the
  pre-branch staging area; a `prototype/` branch is the next graduation step.

### hotfix/vX.Y.Z  (emergency only)
- **Role:** Emergency production fix. Cut from a `master` release tag.
- **Naming:** `hotfix/v{target-version}` (current master patch + 1).
- **Trigger:** Human authorization required. Agents flag `[HOTFIX-CANDIDATE]` only.
- Merged back into `master`. Permanent retention.

---

## 2. Permissions Table

| Branch | Human Devs | master-orchestrator | Builder Agents | release-guardian | GitGrandmaster |
|--------|-----------|---------------------|---------------|-----------------|----------------|
| `master` | Read + merge | Merge owner (work branch -> master) | BLOCKED (no self-merge) | Write (release tag) | Read-only |
| `{feature,bugfix,chore,docs}/dp-NNN-*` | Read / Manage | Spawns + owns lifecycle | Write (own branch only) | Read-only | Read-only (audit) |
| `branding/*`, `council/*`, `prototype/*` | Read / Write | Read / Write | Write (own branch) | Read-only | Read-only |
| `hotfix/vX.Y.Z` | Write (create + resolve) | Read | Write (if assigned) | Write (merge to master) | Read-only |

There is no `develop` row - it no longer exists.

---

## 3. Branch Naming Convention (strict)

Work branches: `{type}/dp-{NNN}-{kebab-slug}`

| Type | Use |
|------|-----|
| `feature` | New feature or capability |
| `bugfix` | Bug fix |
| `chore` | Build, deps, CI, tooling, release prep |
| `docs` | Documentation only |

Meta branches: `{meta-type}/{kebab-slug}` (no dp-NNN)

| Meta type | Use |
|-----------|-----|
| `branding` | Content / marketing / brand material |
| `council` | Council-meeting commits |
| `prototype` | Immature experiment seeds |

**Slug rules (work branches):**
- All lowercase, hyphens only (no underscores, no camelCase)
- Max 65 chars for the slug portion; total branch name <= 80 chars
- Caveman-ultra summary of the ticket's primary intent

**Examples:**
```
feature/dp-085-add-multi-path-config-resolution
bugfix/dp-091-fix-scanner-empty-dir-crash
chore/dp-092-bump-ruff-version
docs/dp-094-update-git-workflow-readme
branding/ux-inaugural
council/inauguration-v2
prototype/camera-sentinel-the-next-step
```

**Invalid patterns (rejected by GitGrandmaster):**
```
develop                        # removed entirely in v3 single-trunk model
agent/sonnet-4-6/dp-085        # legacy format - no type prefix
subagent--...                  # legacy format
ticket/dp-085-scanner          # legacy format - use feature/bugfix/chore/docs
worktree-...                   # legacy format
feature/add-scanner            # missing ticket ID
feature/dp085-scanner          # missing hyphen between dp and NNN
feature/dp-085-Add_Multi_Path  # uppercase + underscores
```

---

## 4. Permanent Branch Retention Policy

**NEVER delete a conforming branch** - `master`, `{feature,bugfix,chore,docs}/dp-NNN-*`,
`branding/*`, `council/*`, `prototype/*`, or `hotfix/*`.

After a work branch merges to `master`:
- Worktree DIRECTORY: removed (`git worktree remove`)
- Branch REF: retained permanently

Rationale: branches are the visual history. The tree view shows exactly when each
agent branched, what it worked on, and when it merged back. Branch refs are cheap
(40 bytes each); the visual history is priceless.

**Enforcement:** `git branch -d` and `git branch -D` are forbidden by convention
(see `permission-model.md`). No agent may delete a conforming branch under any
circumstance.

**One-time exception (2026-06-23 consolidation only).** The single recovery pass
that established the v3 baseline was permitted to delete non-conforming and
pre-convention branches. That exception is closed. It does not recur - deletion is
forbidden going forward.

**Remote push of work branches: NEVER.** Work/meta branches are local-only. Only
`master` and annotated tags are pushed to `origin` (when a remote exists).

---

## 5. Committer Identity Convention

All commits must identify the authoring model. Use `-c` flags on every commit:

```bash
# Main agent (direct implementation, not spawned via Agent tool)
git -c user.name="Opus-4.8" \
    -c user.email="opus-4-8@dev-protocol" \
    commit -m "..."

# Subagent (spawned via the Agent tool - CavecrewBuilder, DnegPipelineBuilder, etc.)
git -c user.name="subagent-Sonnet-4.6" \
    -c user.email="subagent-sonnet-4-6@dev-protocol" \
    commit -m "..."
```

**Model name table:**

| Model | user.name |
|-------|-----------|
| claude-sonnet-4-6 | `Sonnet-4.6` |
| claude-opus-4-8 | `Opus-4.8` |
| claude-haiku-4-5 | `Haiku-4.5` |
| claude-fable-5 | `Fable-5` |
| Subagent of any model | `subagent-{ModelName}` |

The `user.email` follows the pattern `{kebab-model-name}@dev-protocol`. This is a
per-commit override, not a repo config change. The repo's `user.name` (Nikolay)
remains untouched.

---

## 6. Strict Merge Mechanism (single trunk)

1. **Worktree-first (mandatory, always).** The first time an agent session intends
   to modify any file in a git repo, it creates a work branch + worktree BEFORE
   the edit. No exceptions. See git-worktree-hygiene.md §1.
2. **Implementation & Verification:** Changes made and validated inside the
   isolated worktree. Tests, lints, formats all run there.
3. **Commit:** Committer identity (§5), Conventional Commit format. Exponential
   backoff on index.lock: 500ms, 1s, 2s, 4s (5 retries max).
4. **Merge to `master`:** `--no-ff` merge of the work branch into `master`
   (preserves the branch point). There is no `develop` staging tier.
5. **CHANGELOG Sync:** CHANGELOG entry in the same merge (mandatory for
   `feature`/`bugfix`).
6. **Worktree Removal:** `git worktree remove <path>` (working dir only). Branch
   ref is retained (§4).

---

## 7. GitGrandmaster Gate

The GitGrandmaster agent is the gatekeeper for:
- Any proposed change to this rule file
- Any proposed change to `git-worktree-hygiene.md`
- Any proposed change to `git-workflow-golden-standard.md`
- Branch health audits (naming violations, orphaned worktrees, legacy prefixes)

Trigger: "vet this git convention", `/git-grandmaster`, "git audit".
Returns APPROVE / REVIEW / BLOCK.
