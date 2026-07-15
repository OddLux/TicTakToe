---
version: 1.0.0
---

Summon the council for a structured design deliberation. Usage: /summon-the-council [agenda-item...]

Invokes the summon-the-council skill to run an agenda-driven session:
- Each item gets context, debate, verdict
- ADOPTED -> ticket stub or direct implementation
- REJECTED -> decision-ledger entry
- DEFERRED -> TODO.md brain dump
- Session ends with /session-handover package

Optional: pass agenda items inline, e.g. /summon-the-council "naming vote for X" "policy on Y"
