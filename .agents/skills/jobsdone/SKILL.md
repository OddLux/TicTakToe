---
name: jobsdone
description: >
  Ultra-cheap session completion check. Reads git state and goal-state.json to
  answer: is this session's job done? Returns DONE/NOT DONE in <=3 tool calls.
  High confidence threshold -- uncertain = NOT DONE.
  Trigger: /jobsdone, "are we done?", "job done?", "is the task complete?",
  "can I close this session?"
version: 1.1.0
---

# Job's Done?

Peon check. One answer: DONE or NOT DONE.
Named after the Warcraft peon "Job's done!" -- signals work complete, safe to move on.

## Confidence Rule

**Uncertain = NOT DONE.** Threshold: >= 80% confidence required to call DONE.
False "done" (missed unfinished work) is worse than false "not done" (one wasted check).
When in doubt: NOT DONE.

## Execution (3 tool calls max, stop early if answer is clear)

### Step 1 - Working tree + recent commits (1 Bash call)

```bash
git status --short && echo '---' && git log -5 --oneline
```

Signals:
- Any M/A/?? line in git status -> NOT DONE (uncommitted work on disk)
- Clean status + recent commits match apparent session goal -> DONE signal
- Clean status + no commits this session -> uncertain -> proceed to Step 2

### Step 2 - Goal state (1 Read call, skip if Step 1 conclusive)

Determine your active agent provider and locate your provider-specific configuration directory as defined in the `agent-environment-ownership.md` rule (e.g., `~/.claude/` for Claude Code, `~/.gemini/` or `~/.antigravity/` for Gemini/Antigravity).

Read `goal-state.json` from that directory (skip silently if missing or unreadable).

**Session-id guard (apply before reading `state`):**
The sidecar format is `{ "session_id": "<id>", "title": "...", "state": "...", "updated": "..." }`.
- If the file has no `session_id` field -> treat as absent (no signal, rely on Step 1).
- If `session_id` is present and you can verify it matches the live session -> use `state` at full weight.
- If `session_id` is present but you cannot verify the live session id (most common case) -> mark state as **unverified**; weak signal only, must not override a clean git-status from Step 1.

State signals (after guard passes):
- state `done` -> strong DONE (weak DONE if unverified)
- state `review` -> near-DONE, needs user confirm before closing (weak if unverified)
- state `in_progress` or `set` -> NOT DONE
- Absent, unreadable, or missing `session_id` -> no signal, rely on Step 1

### Step 3 - Output

Weigh signals. Apply 80% rule. Print exactly one of:

```
✅ JOB DONE. <evidence in <=10 words>
```
```
🔨 NOT DONE. <what remains in <=10 words>
```
```
❓ UNCLEAR -> NOT DONE. <why uncertain in <=10 words>
```

One extra line allowed only if essential context cannot fit in 10 words.
Never a paragraph. No preamble. No suggestions. Verdict only.

## What This Is Not

- Not a full audit. Does not read every ticket or scan all diffs.
- Not authoritative. Reads visible state, not intent.
- Not a substitute for /session-handover (write that when actually wrapping up).
- Chaotic or goalless session -> default NOT DONE.
