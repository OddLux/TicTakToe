# onboard

Trigger: `/onboard`

Interactive environment setup driver. Runs the `dev-env-setup` playbook as a
live checklist. Auto-runs every check it can; prompts the user for steps it
cannot verify itself. Hard gate: no step advances until PASS and user
confirmation.

Idempotent: safe to re-run. Already-passing checks report OK quickly.

---

## Execution

### Step 0: Load playbook

Read `.agents/playbooks/dev-env-setup.md` to get the full step list.

Print:
```
Running dev-env-setup playbook. Hard gate mode: every check must PASS before advancing.
```

### Step 1: Phase 0 quick scan

Run the Phase 0 batch check command from the playbook.

If all items pass, print the full PASS summary and skip to Phase 3 smoke tests.

### Step 2: Phase 1 - Prerequisite validation

For each step in the Phase 1 table:

1. Run the check command.
2. Evaluate:
   - PASS: print `[OK] Step 1.X - <what>` and advance.
   - FAIL: print `[FAIL] Step 1.X - <what>`. Print the install URL or command. Ask: "Please install it and type 'done' when ready." Re-run check. Repeat until PASS.
3. Do not advance to the next step until current step is PASS.

Auto-fix before asking user:
- uv.lock missing or venv broken: run `uv sync` then re-check Python
- `.claude/settings.local.json` missing and template exists: copy template silently, note it

### Step 3: Phase 2 - Meta-configuration

For each step in the Phase 2 table:
- Agent-runnable checks: run command, evaluate, PASS/FAIL as above.
- User-confirmation steps: print the question, wait for "yes" or "done". Do not advance on anything other than an affirmative.
- Statusline auto-fix: if the active provider's statusline file (`~/.claude/statusline.py` or `~/.antigravity/statusline.py`) is missing, run `uv run python scripts/sync_dotfiles.py --restore` silently, then re-check.

### Step 4: Phase 3 - Smoke tests

Run each smoke test command. Evaluate output.
- sync_agent_configs.py: exits 0 = PASS. Exits non-zero = print output and ask user.
- statusline_doctor.py: exits 0 = PASS. Exits non-zero = print output, note as non-blocking warning.
- /list-tickets: ask user to run it in Claude Code and confirm it returns a backlog table.

### Step 5: Completion summary

Print:
```
SETUP COMPLETE
--------------
Phase 1: X/8 PASS
Phase 2: X/5 PASS
Phase 3: X/3 PASS

Environment ready. Run /list-tickets to see open work.
```

If any step is FAIL and unresolved, print a BLOCKERS table instead and stop.

---

## Auto-fixes (applied silently without asking)

| Problem | Fix |
|---------|-----|
| uv.lock missing or venv broken | `uv sync` |
| Active provider statusline (`~/.claude/statusline.py` or `~/.antigravity/statusline.py`) missing | `uv run python scripts/sync_dotfiles.py --restore` |
| `.claude/settings.local.json` missing + template exists | Copy template |

---

## Manual-only steps (print URL or command, wait for user)

| Problem | What to print |
|---------|--------------|
| VS Code missing | https://code.visualstudio.com/ |
| Git for Windows missing | https://git-scm.com/download/win |
| Node.js missing | `winget install OpenJS.NodeJS` |
| Claude Code CLI missing | `npm install -g @anthropic-ai/claude-code` |
| uv missing | `winget install astral-sh.uv` |
| Python missing | `uv python install 3.12` |
