# Agent Guide & Conventions

This is the **Master Operational Manual** for **TicTakToe**. It defines
how the agent interacts with memory, workflows, and documentation, and is the
canonical reference when the agent needs to make a decision.

---

## Workspace

Three zones for different types of active information:

### 1. `.tickets/` (Tracked Work)

Formal tickets for planned features, bugs, and convention changes.
`open/` = active. `closed/` = done with closing notes recorded.

- See `.tickets/TICKET_TEMPLATE.md` for the format.
- When creating a ticket: use the next ticket ID and update `BACKLOG.md`.
- Closing a ticket always requires a CHANGELOG.md update in the same commit.

### 2. `TODO.md` (Brain Dump)

Paragraph-level brain dumps only - not one-liners, not code comments. Each
entry is a rough description of a feature or idea developed enough to become
a ticket. Not structured, not commitments.

**Lifecycle:** brain dump in `TODO.md` -> convert to a ticket via `/new-ticket`
-> remove the entry from `TODO.md` immediately after the ticket is created.

- Agent: when `TODO.md` has items, offer to convert them to tickets.
- Once an item becomes a ticket (or is executed directly), delete it from
  `TODO.md` in the same action. Never leave a graduated item behind.
- Items that graduate to tracked work become `.tickets/open/` entries.

### 3. `.agents/knowledge/` (Persistent Knowledge)

Agent-maintained reference notes and a running decision log.

- `decision-ledger.md` - design decisions, newest-first. Use `/log-decision`.
- `<topic-slug>.md` - how a feature/subsystem works. Use `/save-knowledge`.

These are NOT subject to triage - they accumulate and stay in the vault.

### 4. `_playground/` (Personal Scratchpad)

Gitignored. User's personal workspace for notes, prompts, and experiments.
Agent: do not read or reference `_playground/` contents unless explicitly asked.

---

## Commands

Slash commands are short invocation stubs in `.agents/commands/`.

| Command | Purpose |
|---------|---------|
| `/new-ticket` | Scaffold a new ticket from TICKET_TEMPLATE.md or IDEA_TEMPLATE.md |
| `/close-ticket` | Mark closed, move to closed/, update BACKLOG.md + CHANGELOG.md |
| `/list-tickets` | Filter and display BACKLOG.md |
| `/log-decision` | Append a decision entry to `.agents/knowledge/decision-ledger.md` |
| `/save-knowledge` | Distill session context into `.agents/knowledge/<topic>.md` |
| `/make-new-build` | Orchestrate full release cycle via chained skills |
| `/fix-venv` | Recover from Windows uv venv lock errors |

## Skills

Skills are detailed instructions in `.agents/skills/<name>/SKILL.md`, discovered
at startup and loaded on demand.

| Skill | Purpose |
|-------|---------|
| `commit-changes` | Stage and commit with full-word Conventional Commit format |
| `derive-version` | Bump version via `uv version --bump` |
| `write-release-notes` | Generate changelog entries from git history |
| `update-readme` | Sync README features and badges with codebase |
| `update-docs` | Sync developer docs after structural changes |
| `log-decision` | Full instructions for `/log-decision` command |
| `save-knowledge` | Full instructions for `/save-knowledge` command |
| `caveman` | Ultra-compressed communication mode (~75% fewer tokens) |
| `caveman-commit` | Terse commit messages - `feature`/`bugfix` types, why over what |
| `caveman-review` | One-line code review comments with severity tags |
| `caveman-help` | Quick-reference card for all caveman modes and skills |
| `cavecrew` | Subagent delegation guide - compressed investigator/builder/reviewer |

## Agents

Cavecrew subagent definitions in `.agents/agents/`. Spawn these to keep main
context lean - each returns caveman-compressed output (~60% smaller than
vanilla), so tool-results consume less main-context budget per delegation.

| Agent | Model | Purpose |
|-------|-------|---------|
| `cavecrew-investigator` | haiku | Read-only code locator. `path:line - symbol - note` |
| `cavecrew-builder` | default | Surgical 1-2 file editor. Refuses 3+ file scope. |
| `cavecrew-reviewer` | haiku | Diff/file reviewer. One-line findings with severity emoji. |

## Workflow Triggers

- Agent notices significant code changes -> suggest `/commit-changes`.
- Agent finishes a task -> review `TODO.md` and offer to convert items to tickets.
- User asks to bump version or prepare release -> run `/make-new-build`.
- `feature`, `bugfix`, or `refactor` commit pending -> update `[Unreleased]` in
  `CHANGELOG.md` before running `commit-changes`.
- After any `feature`, `bugfix`, or `refactor` commit on `master` succeeds ->
  **run `/make-new-build` automatically**. Do not offer; execute. Release on every
  qualifying commit to master.
- After any `git commit` -> print commit receipt (absolute paths, first 10 files,
  `... N more files` if over 10). Never skip.
- `[Unreleased]` block reaches 5 or more `feature`/`bugfix` entries -> **block
  further `feature`/`bugfix` commits**. Require a release first.

---

## Core Conventions

These apply to all artifacts this project produces.

### Versioning

All documents and code artifacts use **Semantic Versioning** (`MAJOR.MINOR.PATCH`).

| Bump | When |
|------|------|
| **Patch** | Typos, small corrections, minor refinements |
| **Minor** | New sections, expanded content, new skills |
| **Major** | Structural overhaul, scope expansion |

- Bumps represent meaningful milestones, not every edit.
- Every versioned document has a `# Version X.Y.Z` header at the top.
- Treat each bump as an intentional publication - like tagging a release.

### Version Source of Truth

- **Python:** `pyproject.toml` `[project].version` is the single source.
  `__version__` derived at runtime via `importlib.metadata` - never hardcoded
  a second time.
- **Bumping:** `uv version --bump patch|minor|major`
- **Dev builds:** PEP 440 format `X.Y.Z.devN`. Used for intermediate
  auto-committed builds.
- **Pre-release progression:** `.devN` -> `rcN` -> stable.
- **Git tags:** `v` prefix (`v1.2.3`). Version strings in code are bare.

### Commit Messages

Conventional Commits with **full-word types**: `type(scope): description`

| Type | Use |
|------|-----|
| `feature` | New feature |
| `bugfix` | Bug fix |
| `docs` | Documentation only |
| `style` | Formatting, no functional change |
| `refactor` | Restructuring, no behavior change |
| `test` | Tests |
| `chore` | Build, deps, CI, tooling, releases |

`feature` and `bugfix` are deliberate full-word forms - an intentional
divergence from Conventional Commits shorthand (`feat`/`fix`).

- **Subject line:** imperative mood, max **100 characters**, no trailing period
- **Scope** (optional): `feature(cli):`, `bugfix(scanner):`
- **Breaking changes:** `feature!:` suffix or `BREAKING CHANGE:` footer
- **Release commits:** `chore: release v1.3.0`
- **Dev bump commits:** `chore: bump v1.3.0.dev2`

### Changelog

Keep a Changelog format in `CHANGELOG.md`. ISO 8601 dates.

- `feature` -> **Added**
- `bugfix` -> **Fixed**
- `refactor` / `style` -> **Changed**
- `docs` (user-facing) -> **Changed**
- `test` / `chore` -> omit unless notable

---

## Agent Behavior

- **Confirm plans** before large or structural changes.
- **Generate commit messages** proactively using the commit types above.
- **Think in commits and diffs.** Treat each artifact as version-controlled.
  When enough work accumulates, ask: *"Would you like to commit these changes
  and bump the version?"*
- **Incremental edits over full rewrites.** Propose snippets, confirm, then
  apply.
- **Cross-reference consistency.** When updating one artifact, check if related
  artifacts need corresponding updates. Standards, rules, skills, and guides
  form a system - they must stay in sync.
- **Distinguish rules from skills.** Always-on conventions are rules.
  Task-triggered workflows are skills. Keep this distinction clear.
- **Be proactive.** Propose smart defaults, suggest structural improvements,
  flag gaps between artifacts. Confirm before irreversible changes.
- **Coding behavior.** See `.agents/rules/coding-behavior.md` - surface
  assumptions, simplicity first, surgical diffs, verifiable success criteria.
  Unrelated improvements are suggested, never silently bundled into a diff.

### Commit Discipline

Never leave file changes uncommitted at the end of a task. All projects are
assumed to be git repos.

| Change type | Rule |
|-------------|------|
| Any implementation, feature, fix, refactor, or config edit | Run `/commit-changes` automatically at end of task |
| Trivial single-line edits (typo, comment tweak) | Ask: "Commit this?" - do not leave it hanging |
| Read-only tasks (grep, audit, explain, plan) | No commit needed |

This applies to all files in the repo - source, docs, tickets, knowledge base,
config. A task is not done until the working tree is clean.

---

## Safety Protocols

- **Turbo Mode**: Read-only operations (`ls`, `grep`, file listing) can be
  auto-run.
- **Safe Mode**: File modifications, moves, deletes, and destructive actions
  REQUIRE user confirmation.
- **Archive Operations**: Always treated as Safe Mode.

---

## Coding Standards

> **Detailed Spec**: See `.agents/rules/coding-standards-python.md` for the full
> technical specification.

- **Style**: Google Python Style Guide + PEP 8.
- **Tooling**: `ruff format` (88 chars) + `ruff check`.
- **Type Hinting**: Minimal by default - only when it genuinely helps.

---

## Documentation Standards

- **User-Facing**: `README.md` (root).
- **Developer-Facing**: `docs/` files.

---

## Communication Style

@.agents/skills/caveman/SKILL.md

Default intensity: **lite**. Drops filler and hedging, keeps full sentences
and articles. Upgrade to `full` or `ultra` only when the user requests it.
Auto-clarity rules in the skill always apply regardless of level.
Active sessions append `🗿 [caveman: <level>]` to the end of every response as a hint.

---

## Exclusions

- **NOTES.todo**: This file is for USER notes only. You must not read, modify,
  or consider it in any context. Treat it as if it does not exist.
