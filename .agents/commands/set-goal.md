---
version: 1.2.0
---

Set the session goal banner. Usage: /set-goal <description>

The goal becomes this chat's dedicated focus and shows in the statusline as
`<emoji> <title>`. See the goal-lifecycle rule for full semantics.

1. Distill <description> to a title: imperative, <=8 words, no trailing period.
2. Read session_id from `statusline-payload.json` in the active provider's configuration directory (e.g. `~/.claude/` for Claude, `~/.antigravity/` or `~/.gemini/` for Gemini/Antigravity).
3. Write `goal-state-<id>.json` (per-session file, where `<id>` is the
   session_id from step 2) to that same directory. The per-session filename
   prevents concurrent sessions from clobbering each other's goal state:
   ```json
   {"session_id": "<id>", "title": "<title>", "state": "set",
    "updated": "<iso8601>"}
   ```
4. Print the optional promotion line for the built-in session name + tab title:
   `/rename 🎯 <title>`
5. Confirm: state `set` (🎯). From now the chat is dedicated to this goal -
   auto-advance state per the goal-lifecycle rule as work proceeds.
