# Version 1.0.0

# Agent Coding Behavior

Always-on rules for how the agent thinks while writing, reviewing, or
refactoring code. They counter four documented LLM failure modes: silent wrong
assumptions, overengineering, drive-by edits, and vague non-verifiable
execution.

Adapted from Andrej Karpathy's guidelines on LLM coding pitfalls
(x.com/karpathy/status/2015883857489522876), as packaged in
github.com/forrestchang/andrej-karpathy-skills (MIT).

These rules bias toward caution over speed. For trivial tasks, use judgment.

---

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

- State assumptions explicitly. If uncertain, ask.
- If multiple interpretations of the request exist, present them - do not
  pick one silently.
- If a simpler approach exists than the one requested, say so. Push back
  when warranted.
- If something is unclear, stop. Name what is confusing. Ask.

**Self-test:** could the user point at any decision in this change and ask
"why did you choose that?" without you having flagged it first? If yes,
surface it before coding.

---

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No unrequested "flexibility" or "configurability".
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

This is the same stance as "minimal type hints by default" in the Python
standards: if a construct is not pulling its weight, delete it.

**Self-test:** would a senior engineer say this is overcomplicated? If yes,
simplify.

---

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

- Do not "improve" adjacent code, comments, or formatting.
- Do not refactor what is not broken.
- Match existing style, even if you would do it differently.
- Remove imports, variables, and functions that YOUR change made unused.
  Do not remove pre-existing dead code unless asked.
- If you notice an unrelated problem or improvement, mention it - suggest a
  `TODO.md` item or a ticket. Never bundle it into the current diff. This is
  how "Be proactive" (AGENTS.md) and surgical scope coexist: suggest, never
  silently do.

**Self-test:** every changed line should trace directly to the user's
request. If a line does not, revert it.

---

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

- Transform imperative tasks into verifiable goals:
  - "Add validation" -> "Write tests for invalid inputs, then make them pass."
  - "Fix the bug" -> "Write a test that reproduces it, then make it pass."
  - "Refactor X" -> "Ensure tests pass before and after."
- For multi-step work, pair every step with a check:
  `1. [Step] -> verify: [command or observable state]`.
- Ticket acceptance criteria are success criteria: each must be a command,
  test, or observable state that can pass or fail - never "works well".
- Tests follow the pytest standards (coding-standards-python.md, section 19).

**Self-test:** if the user walked away, could you verify completion without
asking them? If not, the criteria are too weak - tighten them first.
