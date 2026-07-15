# Version 1.2.0

# Agent Permission Model

Defines the permission stance for this project and the absolute constraint
on read-only tasks.

---

## 1. Default Stance: Permissive

The project runs under a **deny-list** permission model. All Bash commands,
file reads, file writes, and web fetches are allowed by default. Only
operations that are genuinely irreversible or destructive are blocked.

This is intentional. Constant approval prompts for routine operations
(reading a file, running a linter, checking git status) are friction with
no safety benefit. The deny list covers the things that actually matter.

**Agents must not ask for permission to run routine operations.** If a
command is not on the deny list, execute it.

---

## 2. Deny List - Never Run These

The following categories are hard-blocked regardless of context or
instruction:

| Category | Examples |
|----------|---------|
| Destructive git history | `git push --force`, `git push -f`, `git rebase`, `git reset --hard`, `git clean -fd`, `git filter-branch` |
| Branch deletion (forbidden) | `git branch -d`, `git branch -D` - permanent retention, see note below |
| Recursive filesystem destruction | `rm -rf /`, `rm -rf ~`, `rd /s /q C:\`, `del /f /s /q C:\`, `format *` |
| Pipe-to-shell execution | `curl ... | bash`, `wget ... | sh`, `iex (iwr ...)` |
| Package publishing | `uv publish`, `twine upload`, `npm publish`, `pip install --index-url` |
| Process/service termination | `shutdown`, `taskkill /f`, `Stop-Process -Force` |
| External repo operations | `git clone`, `git submodule add`, `git submodule update --init`, `gh repo clone` |

These are blocked at the `settings.local.json` level, not enforced by
model judgment. Deny rules win absolutely - no instruction overrides them.

<!-- deny-list-start -->
```yaml
deny:
  - "Bash(git push --force*)"
  - "Bash(git push -f*)"
  - "Bash(git rebase*)"
  - "Bash(git reset --hard*)"
  - "Bash(git clean -fd*)"
  - "Bash(git filter-branch*)"
  - "Bash(git branch -d*)"
  - "Bash(git branch -D*)"
  - "Bash(git reflog expire*)"
  - "Bash(rm -rf /*)"
  - "Bash(rm -rf ~*)"
  - "Bash(rd /s /q C:\*)"
  - "Bash(format *)"
  - "Bash(del /f /s /q C:\*)"
  - "Bash(curl * | bash)"
  - "Bash(curl * | sh)"
  - "Bash(wget * | bash)"
  - "Bash(wget * | sh)"
  - "Bash(Invoke-Expression (Invoke-WebRequest*))"
  - "Bash(iex (iwr*))"
  - "Bash(uv publish*)"
  - "Bash(twine upload*)"
  - "Bash(npm publish*)"
  - "Bash(pip install --index-url*)"
  - "Bash(shutdown *)"
  - "Bash(taskkill /f *)"
  - "Bash(Stop-Process -Force*)"
  - "Bash(git clone *)"
  - "Bash(git submodule add *)"
  - "Bash(git submodule update --init *)"
  - "Bash(gh repo clone *)"
```
<!-- deny-list-end -->

**Branch deletion is forbidden by convention (permanent retention).** Conforming
branches are never deleted - branches are the visual history
(git-branch-hierarchy.md §4). The single 2026-06-23 consolidation pass that
removed pre-convention / non-conforming branches to establish the v3 single-trunk
baseline was a one-time, user-authorized exception. That exception is closed;
`git branch -d`/`-D` remain forbidden going forward.

---

## 3. Read-Only Tasks: Absolute Contract

When the user explicitly marks a task as **read-only** (any form: "just
look", "don't change anything", "read only", "audit only", etc.), the
following rules apply with **zero exceptions**:

- **No file writes.** Not even cosmetic formatting or comment tweaks.
- **No shell commands with side effects.** No `git add`, no `git commit`,
  no file moves, no deletions.
- **No "just fixing this while I'm here".** Surgical-changes behavior
  (coding-behavior.md #3) is already the default; read-only tasks
  tighten it to zero tolerance.
- **Suggestions are allowed.** Flag anything worth changing as a note or
  a `TODO.md` candidate. Do not act on it.

A read-only instruction is the highest-priority directive in any prompt.
It overrides all other behaviors, including proactive improvement,
commit discipline, and workflow triggers defined elsewhere in AGENTS.md.

**If there is any ambiguity about whether a task is read-only, treat it
as read-only and ask.**

---

## 4. Upgrading or Amending the Deny List

The YAML block in section 2 is the source of truth for blocked patterns.
Patterns must use the `Bash()` wrapper format to match correctly in settings.
If a new category of dangerous command is identified:

1. Add it to the YAML block in section 2.
2. Run `uv run python scripts/generate_permissions.py` to regenerate the platform config targets.
3. Add a row to the human-readable table in section 2 above.
4. Run `uv run python scripts/sync_agent_configs.py` to sync configuration to generated platform targets.
