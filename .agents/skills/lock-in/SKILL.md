---
name: lock-in
description: >
  Focus enforcement protocol. Makes the session aggressively goal-dedicated:
  side issues become new tickets (via the agent-self-ticketing rule) instead of
  inline detours. On a deviation, prints a one-line [LOCK-IN] notice, files the
  ticket, and resumes the primary goal without breaking stride. Default-on while
  a goal is in_progress; explicit-only when no goal is active. Escalates to the
  session-goalkeeper skill at FLAG/DERAIL distraction tiers (goal-lifecycle rule).
  Trigger: /lock-in, "lock in", "stay focused", "no detours", "focus mode".
version: 1.2.0
status: experimental
runs: 0
last-run: never
upgrade-conditions:
  - "agent-self-ticketing threshold changes"
  - "goal-lifecycle states change"
  - "goal-lifecycle distraction tiers change"
---

# Lock-In

Focus enforcement. One job: keep the session pinned to its primary goal. Side
issues get filed, not fixed. Repeated drift escalates to the goalkeeper.

## Activation

When lock-in activates (invoked via `/lock-in`, or auto-triggered on goal
entering `in_progress`), do the following once:

1. **Read the goal sidecar** (`goal-state.json` in the active provider's configuration directory, e.g. `~/.claude/` for Claude, `~/.antigravity/` for Gemini/Antigravity). Extract `title`.
2. **Print the rename command** for the user to run in the prompt bar:
   ```
   /rename 🔒 <title>
   ```
   Example: if title is `statusline doctor bootstrap`, print:
   ```
   /rename 🔒 statusline doctor bootstrap
   ```
   The user types this in their Claude Code prompt to lock the tab name.
   The emoji `🔒` signals focus mode is active in the OS tab title and
   `/resume` list.
3. **Confirm lock-in is active:**
   ```
   [LOCK-IN] active - goal: <title>. Side issues -> ticket. No detours.
   ```
4. **Write the lock-in sidecar** (`lockin-state.json` in the active provider's configuration directory):
   ```python
   import json
   from pathlib import Path
   # Resolve the active provider's directory dynamically (e.g., .claude or .antigravity)
   config_dir = Path.home() / active_provider_dir
   config_dir.joinpath("lockin-state.json").write_text(
       json.dumps({"title": "<goal-title>"}), encoding="utf-8"
   )
   ```

If no goal sidecar exists, use `unnamed goal` as the title and prompt the
user to run `/set-goal <desc>` first.

## Posture

| Condition | Lock-in state |
|-----------|---------------|
| Goal sidecar (`goal-state.json` in active provider config directory) shows `in_progress` | **Default on** - no command needed |
| No active goal, or goal not `in_progress` | **Explicit only** - on when invoked via `/lock-in`, off otherwise |

While on, lock-in is the active posture until the goal leaves `in_progress` or
the user says to drop it ("unlock", "stop lock-in", "normal mode").

On deactivation, delete the sidecar:
```python
from pathlib import Path
# Resolve the active provider's directory dynamically (e.g., .claude or .antigravity)
config_dir = Path.home() / active_provider_dir
p = config_dir / "lockin-state.json"
if p.exists():
    p.unlink()
```

## Behavior

When a side issue or off-goal prompt is detected during locked-in work:

1. **Score distraction tier** per `goal-lifecycle.md` (NUDGE / FLAG / DERAIL).

2. **NUDGE tier** (1 off-goal prompt):
   - Route via `agent-self-ticketing` rule (60-70% threshold, autonomous ticket
     or TODO.md brain dump).
   - Print one line and resume:
     ```
     [LOCK-IN] side issue detected -> filed dp-NNN -> resuming <goal>
     ```
     Below threshold: `-> noted in TODO.md` in place of `-> filed dp-NNN`.

3. **FLAG or DERAIL tier** (2+ consecutive off-goal, or explicit steering away):
   - Invoke the `session-goalkeeper` skill with the appropriate severity before
     responding to the off-goal request.
   - Goalkeeper checks in with the user; lock-in waits for user direction.
   - After user responds to goalkeeper, lock-in resumes its normal posture.

4. **Resume the primary goal immediately** after routing. No expansion of scope,
   no commentary, no "while I'm here."

## Response Label

When lock-in is active, append a label at the end of each response to signal
focus posture. Format mirrors the caveman level label.

**Label format:**
```
🔒 [locked-in: <title>]
```

**When to append:**
- After any implementation, execution, or task-completion reply.
- After a NUDGE or DERAIL routing notice.
- After any reply that advances the active goal directly.

**When to omit:**
- Pure brainstorming or open-ended design discussion where no concrete
  output is produced. The label adds noise when no work boundary is being
  enforced.
- Clarifying questions or one-line factual answers where the label would
  dwarf the response.
- When the response IS the lock-in activation notice itself (avoid double-label).

**Intensity rule:** if caveman mode is also active, place the lock-in label
on the line before the caveman label. Both labels appear together:
```
🔒 [locked-in: <title>]
🗿 [caveman: lite]
```

The label is a passive reminder - it does not replace the `[LOCK-IN]` routing
notices. Those appear inline when routing happens; the label appears at the end
as a persistent state indicator.

## What Lock-In Is Not

- Not a license to fix things inline - the opposite. Even at 90% confidence,
  outside-scope issues are filed, never patched.
- Not a replacement for the self-ticketing rule - it is the posture layer on
  top of it.
- Not a replacement for the goalkeeper - lock-in routes issues mechanically;
  goalkeeper is the conversational check-in layer for sustained drift.
- Not persistent across goals - when the goal changes or completes, the
  posture re-evaluates from the sidecar state.
