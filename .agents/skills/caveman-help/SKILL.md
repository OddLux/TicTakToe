---
name: caveman-help
description: >
  Quick-reference card for all caveman modes, skills, and commands.
  One-shot display, not a persistent mode. Trigger: /caveman-help,
  "caveman help", "what caveman commands", "how do I use caveman".
version: 1.0.0
status: experimental
runs: 0
last-run: never
upgrade-conditions:
  - "new caveman modes or skills added"
---

# Caveman Help

Display this reference card when invoked. One-shot - do NOT change mode or persist anything.
Output in caveman style.

## Modes

| Mode | Trigger | What change |
|------|---------|-------------|
| **Lite** | `/caveman lite` | Drop filler. Keep sentence structure. |
| **Full** | `/caveman` | Drop articles, filler, pleasantries, hedging. Fragments OK. Default. |
| **Ultra** | `/caveman ultra` | Extreme compression. Abbreviate prose. Arrows for causality (X -> Y). |

Mode stick until changed or session end.

## Skills

| Skill | Trigger | What it do |
|-------|---------|-----------| 
| **caveman-commit** | `/caveman-commit` | Terse commit messages. `feature`/`bugfix` types. 100-char cap. Why over what. |
| **caveman-review** | `/caveman-review` | One-line PR comments: `L42: 🔴 bug: user null. Add guard.` |
| **caveman-help** | `/caveman-help` | This card. |
| **cavecrew** | phrase-triggered | Subagent delegation guide. Compressed investigator/builder/reviewer. |

## Deactivate

Say "stop caveman" or "normal mode". Resume anytime with `/caveman`.
