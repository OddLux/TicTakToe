---
name: audit-agent-access
description: >
  Audits the full agent access surface: permission allow/deny lists in Claude
  settings JSON files, tool grants in subagent definitions, and sync between
  the enforced deny list and the permission-model rule doc. Produces a
  standard report with per-entry risk classification and a verdict. Generic -
  works in any project with a .claude/ directory. Trigger: /audit-agent-access,
  "audit permissions", "what commands are agents allowed", "review the deny
  list", project .claude/settings.json or .claude/settings.local.json
  permissions changed.
version: 1.0.0
status: experimental
runs: 0
last-run: never
upgrade-conditions:
  - "settings.json schema changes"
  - "new permission categories added"
---

# Agent Access Audit

One consistent pass over everything that grants or blocks agent capability.
Answers: *what are my agents allowed to do right now, and is that what the
docs say they're allowed to do?*

Read-only by default. Only writes files when the user accepts a proposed fix.

---

## Audit surface

Collect every layer, in precedence order. Skip layers that don't exist.

| Layer | Location | What to extract |
|-------|----------|-----------------|
| Enterprise/managed | managed settings (if visible) | note existence only |
| User settings | Active provider's settings.json (e.g. `~/.claude/settings.json` or `~/.antigravity/settings.json`) | `permissions.allow/deny/ask` |
| Project settings | `.claude/settings.json` | `permissions.allow/deny/ask` |
| Project local | `.claude/settings.local.json` | `permissions.allow/deny/ask` |
| Subagent tool grants | `.agents/agents/*.md`, `.agents/profiles/*/agents/*.md` (or `.claude/agents/*.md` if no `.agents/`) | frontmatter `tools:` + `model:` |
| Hooks | any settings file `hooks` block | commands hooks execute |
| Policy doc | `.agents/rules/permission-model.md` (or equivalent rule doc) | documented deny categories |

Precedence reminder when reporting: deny beats allow at every level; more
specific scope does not override a deny.

---

## Checks

Run all six. One finding per line; skip a check silently only if its layer
is absent.

### 1. Allow-list breadth

Classify each `allow` entry:

| Class | Pattern | Note |
|-------|---------|------|
| `BLANKET` | `Bash(*)`, `Write(*)`, tool with bare `*` | full capability - flag, but accept if the project declares a permissive deny-list model |
| `BROAD` | prefix wildcard spanning many commands (`Bash(git *)`) | fine if intentional |
| `SCOPED` | specific command or path (`Bash(npm test)`) | ideal |

### 2. Deny-list coverage

Check the merged deny list against the baseline destructive categories.
Flag any category with zero matching entries:

- Git history destruction (`push --force`, `reset --hard`, `clean -fd`, `filter-branch`)
- Recursive filesystem deletion (`rm -rf /`, `rd /s /q`, `del /f /s /q`)
- Pipe-to-shell (`curl|bash`, `wget|sh`, `iex`/`Invoke-Expression`)
- Package publishing (`npm publish`, `uv publish`, `twine upload`)
- Process/system termination (`shutdown`, `taskkill /f`, `Stop-Process -Force`)
- Credential/secret exfiltration paths if the project handles secrets

### 3. Dead and shadowed entries

- Deny entries that can never match (typo'd pattern, wrong tool name,
  malformed glob).
- Allow entries fully shadowed by a deny at the same or higher level.
- Duplicate entries across files (same rule in local + project settings).

### 4. Doc/enforcement sync

Diff the policy doc's deny table against the actual merged deny list:

- Documented category with no enforcing entry -> `DOC ONLY` (gap).
- Enforced entry in no documented category -> `UNDOCUMENTED` (drift).

If no policy doc exists, report that and suggest one; don't fail the audit.

### 5. Subagent tool grants

For each agent definition, compare granted tools against its described job:

- Agent described as "read-only" but granted `Write`, `Edit`, or
  unrestricted `Bash` -> flag `OVERGRANT`.
- Agent granted `Bash` (Bash inherits the settings allow/deny, but a
  blanket allow means subagents get it too) -> note which agents can
  execute commands.
- `tools: *` or missing `tools:` (inherits everything) -> flag for
  agents that don't need it.

### 6. Hook commands

Hooks execute outside permission prompts. List every hook command and flag
any that fetch remote content, pipe to shell, or run with elevated scope.

---

## Output format

```
AGENT ACCESS AUDIT: <project-name>
  layers found     › <list of settings files + agent dirs scanned>
  allow            › <N> entries: <X> BLANKET, <Y> BROAD, <Z> SCOPED
  deny             › <N> entries; coverage: <ok | missing: <categories>>
  dead/shadowed    › <"none" | list>
  doc sync         › <"in sync" | "DOC ONLY: ..." | "UNDOCUMENTED: ...">
  agent grants     › <agent: tools summary, one line each; flag OVERGRANT>
  hooks            › <"none" | command list with flags>
  verdict          › <CLEAN | REVIEW | UNSAFE>
  fixes            › <numbered concrete edits, or "none">
```

**Verdict rules:**

| Verdict | Condition |
|---------|-----------|
| `CLEAN` | Deny coverage complete, docs in sync, no overgrants. Blanket allows are OK under a declared deny-list model. |
| `REVIEW` | Soft findings: drift between doc and enforcement, dead entries, an overgrant with plausible justification. |
| `UNSAFE` | A baseline destructive category is unblocked, a hook pipes remote content to shell, or a read-only agent can write. |

---

## After the audit

- `CLEAN`: report and stop.
- `REVIEW` / `UNSAFE`: propose each fix as a concrete settings/frontmatter
  edit. Apply only what the user accepts. When the deny list changes, update
  the policy doc's table in the same change (permission-model.md section 4
  procedure, where that rule exists).
