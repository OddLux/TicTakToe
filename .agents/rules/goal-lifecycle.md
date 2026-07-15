# Version 1.3.0

# Goal Lifecycle

Always-on convention for the session goal banner. A chat is dedicated to one
goal at a time; the goal is summarized in the statusline title and progresses
through a fixed set of states until achieved or replaced.

---

## Sidecar

State lives in a **per-session** file in the provider-specific configuration
directory: `goal-state-{session_id}.json` (e.g.
`~/.claude/goal-state-{session_id}.json` for Claude or
`~/.antigravity/goal-state-{session_id}.json` for Gemini/Antigravity). One file
per session means concurrent sessions never clobber each other's goal state -
the old single shared `goal-state.json` was overwritten on every write,
destroying any other live session's goal.

```json
{ "session_id": "<id>", "title": "<=8-word imperative goal",
  "state": "set|in_progress|review|done", "updated": "<iso8601>" }
```

`statusline.py` reads `goal-state-{session_id}.json` for the live session and,
when the `session_id` field matches, renders `<emoji> <title>` in the
session-name slot of line 1 - taking precedence over the built-in
`session_name`. For one migration cycle it falls back to the legacy shared
`goal-state.json` when the per-session file is absent. Absent file, malformed
JSON, or a session mismatch falls back silently to `session_name`.

## States

| State | Emoji | Meaning |
|-------|-------|---------|
| `set` | 🎯 | Goal contextualized, chat now dedicated to it |
| `in_progress` | 🔄 | Actively being worked |
| `review` | 👀 | Acceptance criteria met, awaiting user review |
| `done` | ✅ | Achieved - chat can be closed or the goal replaced |

## Auto-advance

The model updates `state` itself as work proceeds - no command needed:

- `set` -> `in_progress` when implementation work on the goal begins.
- `in_progress` -> `review` when the goal's acceptance criteria are met
  (ties into goal-driven-execution, `coding-behavior.md` #4 - the same
  verifiable success criteria gate the transition).
- `review` -> `done` **only on explicit user confirmation**. Never
  self-declare a goal done.

`/goal-state <state>` is a manual override. `/set-goal <desc>` creates or
replaces the goal (resets to `set`).

## Built-in session name (manual bridge)

`session_name` is **not** model- or hook-writable - it is set only by the user
typing `/rename` or launching with `--name`. To land the goal in the built-in
`/resume` list and OS tab title, `/set-goal` prints a ready `/rename 🎯 <title>`
line for the user to run. This is optional; the statusline banner works without
it.

---

## Distraction Tiers

When goal state is `in_progress`, score each user prompt for goal alignment.
Track consecutive off-goal prompts in-context (resets when user returns to goal):

| Tier | Condition | Handler |
|------|-----------|---------|
| `NUDGE` | 1 off-goal prompt | Lock-in: file/brain dump, one-line notice, resume silently |
| `FLAG` | 2 consecutive off-goal prompts, OR user explicitly steering away | Invoke `session-goalkeeper` with `severity=FLAG` |
| `DERAIL` | 3+ consecutive off-goal, OR user announces new task without closing goal | Invoke `session-goalkeeper` with `severity=DERAIL` |

Consecutive counter resets on any prompt that re-engages with the active goal.

## Goalkeeper Escalation

When distraction tier reaches FLAG or DERAIL, invoke the `session-goalkeeper`
skill before responding to the off-goal request. The goalkeeper checks in with
the user; the model waits for user direction before proceeding.

Goalkeeper is dormant when:
- No goal is active (`goal-state.json` absent or `session_id` mismatches live session)
- Goal state is `set`, `review`, or `done` (only fires during `in_progress`)
- Goalkeeper silence sidecar (`goalkeeper-state.json` in the active provider's configuration directory) shows `silence_turns > 0`
  for the current session
