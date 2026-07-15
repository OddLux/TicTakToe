# Version 1.0.0

# uv Canonical Python Runner

All Python invocations by agents, skills, subagents, and playbooks MUST use
`uv run`. Never call bare `python` or `python3`.

---

## 1. The Rule

- **Always `uv run`.** Every command that executes Python goes through
  `uv run`. This guarantees the project's pinned interpreter and dependency
  environment.

### Correct forms

```bash
uv run python scripts/sync_agent_configs.py
uv run python <script>
uv run <entry-point>
```

### Wrong forms

```bash
python scripts/foo.py      # bad - hits system Python
python3 scripts/foo.py     # bad - hits system Python
```

---

## 2. Why

Bare `python` / `python3` resolves to whatever interpreter happens to be first
on `PATH` - usually system Python. That means:

- Wrong environment (no project venv).
- Missing dependencies (project packages not installed).
- Machine-specific failures (works on one box, breaks on another).

`uv run` resolves the correct interpreter and dependency set every time, so the
same command behaves identically across machines.

---

## 3. Scope

This rule applies to **all** `.agents/` instructions - skills, playbooks,
rules, agent definitions, and commands - that tell a user or agent to run a
Python script. When authoring or editing any of these, write `uv run python ...`,
never bare `python ...`.

---

## 4. Exception: Bootstrap Context

Before `uv` is installed, there is no `uv run`. In bootstrap docs (quickstart,
onboarding), it is fine to **print the install command for the user** so they
can set up `uv` themselves:

```bash
winget install astral-sh.uv
```

Do not invoke such bootstrap commands as an agent command - print them for the
human to run. Once `uv` is present, all subsequent Python calls revert to the
`uv run` form.

---

## 5. Base SLA Contract

`uv` is a base SLA contract item: it must be installed and working before the
harness is usable. Onboarding (`/onboard`, the `dev-env-setup` playbook)
verifies `uv --version` and `uv run python --version` before declaring the
environment ready.
