# Version 2.0.0

# Git Worktree Hygiene

Rules and conventions for managing isolated git worktrees under the single-trunk
model. Follow these guidelines to prevent lock collisions, EEXIST errors, and
stale worktree accumulation.

---

## 0. Worktree-First Mandate (always on)

**The first time any agent session intends to modify a file in a git repo, it
MUST create a work branch + worktree BEFORE the edit.** No exceptions. This holds
for the main thread and every spawned writer agent alike. A session never edits
files directly on `master` (or on a checked-out work branch in the primary
working directory) - it branches into a worktree first, works there, then merges
to `master` (git-branch-hierarchy.md §6).

The only sanctioned exception is a one-time meta-operation explicitly authorized
by the user (e.g. the 2026-06-23 git consolidation), where the trunk itself is
the subject of the change.

---

## 1. Naming Conventions

To prevent collision on checked-out branches and directory names, every writer
agent must use unique identifiers.

### Branch Names
- Pattern: `{type}/dp-NNN-{slug}` - the work-branch scheme from
  `git-branch-hierarchy.md` §3. `{type}` is `feature`/`bugfix`/`chore`/`docs`;
  `dp-NNN` is the ticket being worked; `{slug}` is a caveman-ultra summary.
  Append a short disambiguator when multiple agents work the same ticket in
  parallel: `feature/dp-038-backlog-rules-a82e`.
- Example: `feature/dp-038-backlog-refiner-command`, or
  `feature/dp-038-refiner-builder-a82e` for a second concurrent agent.
- **Never** share a branch name between two active agents or check out a branch
  currently checked out in another worktree.
- Legacy prefixes (`agent/`, `subagent`, `ticket/`, `worktree-`) are forbidden -
  they were removed in the v3 consolidation.

### Worktree Directories
- Worktrees must be created under `.claude/worktrees/` (or client sandbox directories) with unique folder names matching the branch's `dp-NNN` (plus slug if present).
- Example: `.claude/worktrees/dp-038/` or `.claude/worktrees/dp-038-builder-a82e/`

---

## 2. Directory Creation EEXIST Race

When spawning multiple worktree agents, simultaneous directory creation can cause `EEXIST` errors.
- **Rule:** When creating `.claude/worktrees/`, check if the parent directory already exists. If a race condition occurs (`mkdir` fails because the directory was just created by another thread), catch the error and proceed.
- **Master Orchestrator:** If spawning multiple write agents, introduce a delay of at least 1 second between spawns to ensure directory structures do not collide during initialization.

---

## 3. Git Lock Collision Resolution

Git worktrees share the same central `.git` metadata store. If multiple agents attempt git writes simultaneously (such as `git checkout`, `git add`, or `git commit`), Git will lock the repository with `.git/index.lock` or `.git/refs/heads/<branch>.lock`.

- **Rule:** If a git command fails with a lock error (`index.lock` or `lock file exists`), the agent **must** retry the command using exponential backoff:
  1. Wait `500ms`, retry.
  2. Wait `1000ms`, retry.
  3. Wait `2000ms`, retry.
  4. Wait `4000ms`, retry.
  5. If it still fails after 5 attempts, report the collision explicitly and wait for user intervention.

---

## 4. Commit Discipline

- **Rule:** Every agent executing in a worktree must run `git add` and `git commit` to persist its changes to its isolated branch before completing.
- An empty branch is a failure. Never exit a worktree leaving modified files unstaged.

---

## 5. Cleanup Protocol

Stale worktree DIRECTORIES pollute the file system. The main thread removes them
immediately after merging - but **NEVER deletes the branch ref** (permanent
retention, git-branch-hierarchy.md §4).

### Standard Cleanup
```bash
# Remove ONLY the worktree directory. The branch ref is retained permanently.
git worktree remove --force .claude/worktrees/<worktree-name>
# Do NOT run `git branch -d/-D` - branch deletion is forbidden by convention.
```

### Windows-Specific Recovery (Permission Denied)
If the standard removal fails because a file handle is locked by an editor or python process:
```bash
git worktree prune
# Then remove the orphaned directory with your platform's file tools.
```
