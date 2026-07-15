---
name: dotfiles-sync
description: >
  Backup or restore tracked dotfiles between the dev-protocol repo and the
  live home directory. Runs scripts/sync_dotfiles.py. Tracked files:
  .bash_profile, .bash_aliases, .bashrc, statusline.sh, statusline.py
  (.claude/, .antigravity/). Trigger: user asks to back up dotfiles, sync
  dotfiles, or restore dotfiles.
version: 1.1.0
status: experimental
runs: 0
last-run: never
upgrade-conditions:
  - "new dotfiles added to tracking list"
  - "sync_dotfiles.py path changes"
---

# Dotfiles Sync

Back up live home-dir dotfiles into the repo, or restore them from the repo.

Tracked files live in `dotfiles/` at the repo root:

```
dotfiles/
  .bash_profile
  .bash_aliases
  .bashrc
  .claude/
    statusline.sh
    statusline.py
  .antigravity/
    statusline.sh
    statusline.py
```

## Usage

```
/dotfiles-sync [backup|restore|status]
```

If no argument given, default to `backup`.

---

## Steps

### 1. Resolve direction

| Argument | Direction | What happens |
|----------|-----------|--------------|
| `backup` (default) | home -> repo | Copies live files into `dotfiles/` |
| `restore` | repo -> home | Copies repo files back to home dir |
| `status` | read-only | Shows which files are in sync / out of sync |

### 2. Run the script

**backup:**
```bash
uv run python scripts/sync_dotfiles.py
```

**restore:**

**Warning:** This overwrites live files in your home directory. Confirm with the user before running.
```bash
uv run python scripts/sync_dotfiles.py --restore
```

**status (dry run):**
```bash
uv run python scripts/sync_dotfiles.py --dry-run
```

### 3. Report output

Print the script output verbatim so the user can see which files changed.

### 4. On backup: offer to commit

If any files were modified or created, ask:
> Files updated in `dotfiles/`. Commit these changes?

If yes, stage and commit with:
```
chore(dotfiles): sync dotfiles backup
```

---

## Adding new files to track

Edit the `DOTFILES` list in `scripts/sync_dotfiles.py`:

```python
DOTFILES = [
    (HOME / ".bash_profile", REPO_ROOT / "dotfiles/.bash_profile"),
    # add new entries here: (source_path, repo_path)
]
```

Then run `uv run python scripts/sync_dotfiles.py` to capture the initial snapshot.
