---
version: 1.0.0
---

Summon the project-grandmaster for a historical release-arc audit.
Usage: /grandmaster-audit [--depth N]

1. Spawn the `project-grandmaster` agent (Opus). Pass the depth (default 20,
   hard cap 50).
   Spawn label (per agent-spawn-labeling rule):
   `[opus-4.8] project-grandmaster: audit last <N> commits vs protocol`
2. The agent reads the commit window + protocol surface, works the four nags
   (cadence, prod-readiness, docs, release value), runs the golden-brief
   fidelity pass, and writes `.agents/knowledge/grandmaster-audit-<date>.md`.
3. Relay its verdict block (PASS | HOW-ABOUT-NO) to the user. The agent is
   read-only - it edits nothing and opens no tickets; surface its suggested
   tickets as offers.

v1 is a lenient proto: it only blocks on syntax errors or release-critical
breakage. Everything else is nagged, not gated. See dp-053 for his evolution.
