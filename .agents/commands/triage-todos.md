---
version: 1.0.0
---

Two-tier TODO triage with feature creep gate. Usage: /triage-todos [path]

Without [path]: triages TODO.md brain dumps (Path B - slow path).
With [path]: scans inline # TODO: markers in code files (Path A - fast path).

1. Load decision-ledger.md, CHANGELOG.md, BACKLOG.md for cross-checking.
2. Parse/scan entries; extract core ask from each (strip filler for brain dumps).
3. Cross-check each item: CONFLICT / ALREADY SHIPPED / DUPLICATE - wait for user choice.
4. Run feature creep gate per item (Q1: done criteria, Q2: coupling, Q3: MVP).
5. Present proposed ticket; wait for confirm.
6. Create tickets, update TODO.md / mark inline TODOs handled.
7. Run /commit-changes.
