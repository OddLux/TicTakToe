# Version 1.1.0

# Agent Spawn Labeling

Every Agent tool call MUST include a `description` field that encodes model
version, effort level, agent type, and task. This is the only identifier
visible in the agent UI - make it self-describing.

## Format

`[model-version] agent-type: ticket-or-task`

Short model strings: `sonnet-4.6`, `haiku-4.5`, `opus-4.8`, `fable-5`.

```
[haiku-4.5] CavecrewInvestigator: statusline - find context_window fields in payload
[sonnet-4.6] CavecrewBuilder: dp-037 - write BacklogRefiner command stub
[opus-4.8] CavecrewReviewer: validate threshold-delegation plan
[sonnet-4.6] GeneralPurpose: dp-038 - implement builder commit discipline
[sonnet-4.6] CavecrewBuilder: dp-085 - fix scanner path [wt]
```

## Effort tag

Effort tag omitted entirely. Effort does not propagate reliably to spawned agents
(see `.agents/knowledge/effort-telemetry-postmortem.md`). Including it in labels
is noise.

## Worktree flag

Append `[wt]` at the end of the description when spawning with
`isolation: "worktree"`. Cheap, high diagnostic value when multiple agents
are live simultaneously.

## Enforcement

No exceptions. A description that omits model version or agent type is
non-compliant. Fix before spawning.
