# Version 1.0.0

# Planning Mode SLA

Always-on rule. Whenever the agent presents an implementation plan -- in plan
mode or inline -- it must save the full plan to a file and print a Caveman
Ultra summary in-chat. The full plan is never rendered in-chat unless the
user explicitly asks.

---

## 1. Trigger

Any of:
- Agent enters plan mode (EnterPlanMode called)
- Agent says "here is the plan", "implementation plan", or equivalent
- Agent uses AskUserQuestion to propose a multi-step approach
- User invokes `/plan`, "show me a plan", "how would you approach this"

---

## 2. SLA Contract (3 steps, always)

### Step 1 -- Save full plan to file

Write the full implementation plan to a file. Location priority:

1. If an active session package exists (`.agents/sessions/YYYY-MM-DD_<3-word>/` already
   created this session): save to `plans/plan-<3-word>.md` inside that package.
2. Otherwise: save to `tmp/plan-<3-word>.md` in the active provider's configuration directory (e.g. `~/.claude/tmp/` for Claude, `~/.antigravity/tmp/` for Gemini/Antigravity)

Use a 3-word slug for the plan filename. Derive from the plan's subject:
- Take the first 2 significant words from the goal or task description (kebab-case)
- Append a 3rd word derived from the current time (e.g. `hex(time % 4096)` as a word, or just a short noun)
- Example: goal "upgrade handover skill" -> `upgrade-handover-loaf`

### Step 2 -- Print Caveman Ultra summary in-chat

Immediately after saving, print a Caveman Ultra summary of the plan:
- What is being built/changed (one line)
- Key decisions made (bullet per decision, one line each)
- Files to touch (list)
- Sequence (numbered, one line each)

Cap: ~15 lines total. No prose. Arrows for causality.

### Step 3 -- Print path

Print the full Linux-style path to the saved plan file.
Format: `Full path: /c/path/to/plan-<3-word>.md`

---

## 3. In-Chat Expansion

Full plan content is rendered in-chat **only** when the user explicitly asks:
- "show me the plan"
- "expand"
- "full plan"
- "what's in the plan file"

Otherwise: summary + path only. Trust the file.

---

## 4. Plan File Format

```markdown
# Implementation Plan: <title>
3-word-id: <word>-<word>-<word>
Date: YYYY-MM-DD
Scope: <one-line scope>

---

## Council Decisions
<numbered list of design decisions with rationale>

## Files to Create/Modify
### Create
- <path> (<why>)
### Modify
- <path> -- <what changes>

## Sequence
1. <step> -> verify: <how to check>
2. ...

## Open Questions / Deferred
- <item>
```

---

## 5. Relationship to Session Package

When a session package (`.agents/sessions/<package>/`) is active, all plans
saved this session live under its `plans/` subdirectory. The package `manifest.toml`
lists them. This links plans to the handover artifact automatically.

When no package is active, plans live in the active provider's configuration `tmp/` directory and are ephemeral.
A loaf handover (session-handover --loaf) will attempt to pull them in if the
paths are still valid.
