---
version: 1.0.0
---

Audit agent access surface. Usage: /audit-agent-access

Read-only sweep of everything that grants or blocks agent capability.

1. Load the `audit-agent-access` skill from `.agents/skills/audit-agent-access/SKILL.md`.
2. Collect layers: user/project/local settings JSON, agent `tools:` frontmatter, hooks, permission-model rule doc.
3. Run all six checks (allow breadth, deny coverage, dead/shadowed, doc sync, agent grants, hooks).
4. Print the AGENT ACCESS AUDIT block with verdict CLEAN / REVIEW / UNSAFE.
5. Propose fixes; apply only on user accept.
