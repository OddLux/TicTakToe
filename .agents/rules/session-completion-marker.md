# Version 1.0.0

# Session Completion Marker Rule

To prevent cognitive clutter and avoid feeding old, stale session contexts into new agent runs, a completed development session must be explicitly stamped with a standardized completion marker.

## 1. Trigger
This rule applies when:
- The session goal is successfully achieved.
- A ticket is successfully completed and marked as closed.
- The `/jobsdone` checks or `jobsdone/SKILL.md` returns a `DONE` verdict.
- The agent is delivering the final response for the task.

## 2. Completion Marker Format
At the very end of the final response, following the caveman level visual indicator, the agent must append the jobsdone completion marker:
`🗿 [jobsdone: done]`

Example final lines of a completed response:
```
🗿 [caveman: ultra]
🗿 [jobsdone: done]
```

## 3. SLA & Resumption Guard
The presence of `[jobsdone: done]` serves as an SLA guarantee. If a future agent resumes in this workspace or reads this log, it must treat this session as completely finalized. It must not attempt to resume or pull context from this session's decisions or files unless explicitly instructed by the user.
