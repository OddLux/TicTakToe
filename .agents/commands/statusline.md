---
version: 1.0.0
---

Set up, verify, or audit the Claude Code statusline. Usage: /statusline

1. Spawn the `statusline-engineer` agent (Sonnet).
   Spawn label (per agent-spawn-labeling rule):
   `[sonnet-4.6] statusline-engineer: setup/audit statusline`
2. The agent runs `scripts/deploy_statusline.py --check` to pick its verb:
   missing runtime files -> SETUP (deploy + wire + stamp meta + verify);
   else -> AUDIT (schema drift + cognitive-load pass).
3. Relay its verdict. On SETUP success, remind the user to restart Claude Code.

Replaces the retired `/statusline-doctor` and `/setup-claude-statusline`
commands and their skills (see dp-030).
