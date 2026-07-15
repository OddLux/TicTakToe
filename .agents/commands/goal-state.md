---
version: 1.1.0
---

Advance the current goal's state. Usage: /goal-state <set|in_progress|review|done>

1. Read `goal-state-<session_id>.json` (per-session file) from the active provider's configuration directory (e.g. `~/.claude/` for Claude, `~/.antigravity/` or `~/.gemini/` for Gemini/Antigravity). Resolve `<session_id>` from `statusline-payload.json` in that same directory. If absent, tell the user to run /set-goal
   first and stop.
2. Set `state` to the given value and refresh `updated` (iso8601). Keep
   `session_id` and `title` unchanged.
3. Confirm with the matching emoji: set 🎯, in_progress 🔄, review 👀, done ✅.
4. On `done`: note the chat's goal is achieved - it can be closed or replaced
   with a new /set-goal.

The model also auto-advances state without this command (see goal-lifecycle
rule); use this for manual override.
