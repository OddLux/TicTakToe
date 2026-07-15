---
version: 1.0.0
---

Enter lock-in focus mode. Usage: /lock-in

Invoke the `lock-in` skill. The session becomes aggressively goal-dedicated:
side issues are filed as tickets via the `agent-self-ticketing` rule instead
of being fixed inline. On each deviation, print:

```
[LOCK-IN] side issue detected -> filed dp-NNN -> resuming <goal>
```

Lock-in is default-on while a goal is `in_progress` (goal-lifecycle rule);
this command is the explicit trigger when no goal is active.
