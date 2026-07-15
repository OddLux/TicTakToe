# Home Dir Session State

**Date:** 2026-06-18
**Concept:** What lives in ~/.claude3/ (provider config dir) and why the scrutinizer should leave it alone
**State:** ready-for-scribe

## Stream

The provider configuration directory -- `~/.claude3/` on this machine, canonically `~/.claude/` -- holds a parallel notion of "session" that is entirely machine-local and ephemeral. The SessionScrutinizer validates committed repo artifacts, not this. But it needs to know what's there so it never mistakes it for a session package and never crosses the provider boundary.

What I observed in `~/.claude/` and `~/.claude3/`:
- `session-cost.json` -- stop-hook cost estimate, rewritten every session by `scripts/session_cost.py`.
- `goal-state.json` plus a fleet of `goal-state-{session_id}.json` (six of them, UUID-keyed). Per-session goal banner state, per the goal-lifecycle rule. The legacy shared `goal-state.json` still lingers for one migration cycle.
- `harness-meta.json` -- statusline stamp.
- `statusline-bridge.json`, `statusline-payload.json` -- live statusline render inputs, rewritten on essentially every keypress.
- `sessions/` (a directory of per-session state, JSONL/JSON keyed by UUID), `tmp/`, `plans/`, `shell-snapshots/`, `history.jsonl`, `effort-cache.json`, `lockin-state.json`, `caveman-state.json`, daemon/jobs/tasks dirs.

Every one of these is transient machine state. It is not committed. It is overwritten constantly. It is per-machine and per-provider. None of it is a "session artifact" in the sense the scrutinizer audits -- the scrutinizer audits the repo's `.sessions/` and `.agents/sessions/` trees, which are version-controlled deliverables. Validating ephemeral JSON that changes between two reads would be pointless and noisy.

There is also a hard rule in play: `agent-environment-ownership.md` section 5, "Strict Separation of Provider State." A Claude agent must operate only within `~/.claude/`; it must NEVER touch `~/.gemini/` or `~/.antigravity/`. So even if the scrutinizer wanted home-dir context, it is fenced to its own provider's dir, and the spirit of the rule (ephemeral state is not shared substrate) argues against reading any of it for validation.

That said, there is ONE genuinely interesting cross-reference: `goal-state-{session_id}.json` carries a `title` (the <=8-word goal). A repo session slug should plausibly cohere with the goal that was active when it was created. "Does the session slug match the goal title?" is a coherence check the scrutinizer COULD offer -- e.g. a `.sessions/raw-photo-research/` next to a goal-state titled "research RAW photo ingestion" is coherent; a wild mismatch is a smell. But this requires reading home-dir state, which collides with the "audit committed artifacts only" principle and the provider-boundary caution. My instinct: keep the scrutinizer repo-only by default. If goal-coherence is ever wanted, gate it behind an explicit flag and read only `~/.claude/goal-state*.json`, never anything else, never another provider's dir.

## Shape so far

- `~/.claude3/` (canonically `~/.claude/`) holds ephemeral per-session machine state: cost JSON, goal-state JSON (UUID-keyed), statusline payloads, sessions/, tmp/, history.jsonl, effort/lockin/caveman caches.
- All of it is uncommitted, constantly overwritten, per-machine, per-provider.
- Scrutinizer does NOT validate it -- it audits committed repo session trees only.
- `agent-environment-ownership.md` 5 forbids crossing into other providers' dirs; ephemeral state is not shared substrate.
- One possible value-add: goal-title (from goal-state JSON) vs session-slug coherence -- but it breaks the repo-only principle.

## Still unresolved

- Should the scrutinizer ever read home-dir files at all, or stay strictly repo-only? I lean strictly repo-only.
- If goal-coherence is added, how to map a UUID-keyed goal-state file to a repo session folder that has no session_id recorded (Type B has no manifest/session_id)?
- Type A `manifest.toml` could carry session_id to enable the link cleanly -- but current manifests don't. Worth a convention proposal, not a scrutinizer feature.
