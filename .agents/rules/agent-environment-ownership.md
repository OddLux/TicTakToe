# Version 1.4.1

# Agent Environment Ownership

Ownership of runtime configuration - statusline, hooks, settings, sidecar
files, and the like - is **per agent provider**, not per instance. All Claude
instances share one environment; all Gemini/Antigravity instances share
another. Each provider is responsible for setting up and maintaining its own
environment. Do not cross-configure another provider's environment from yours.

This is a soft convention, not a hard gate. The point is to prevent drift:
when one provider edits another's config, the two fall out of sync and nobody
owns the divergence.

---

## 1. The Directive

- **Provider is the boundary.** The unit of ownership is the provider (Claude,
  Gemini, and any future one) - not a single chat or instance. Instances of the
  same provider share the same statusline, hooks, and settings, so any instance
  may maintain them.
- **Own your bar.** Claude owns the Claude statusline (`dotfiles/.claude/`,
  `~/.claude/`). Gemini/Antigravity owns the Antigravity statusline
  (`dotfiles/.antigravity/`, `~/.antigravity/`). Same for any future provider.
- **Don't reach across.** When running as one provider, do not set up or rewrite
  another provider's statusline, hooks, or settings just because the files are
  visible in this repo. Surface the idea instead and let that provider apply it.
- **Share patterns, not edits.** A good convention (e.g. the effort cache +
  `*` display) can be a *golden standard* others copy. Reference it; let each
  provider's environment owner port it themselves.

## 2. Why

- Each provider's runtime has details only that provider reliably knows
  (payload schema, config path, available fields). Cross-edits guess and rot.
- Single ownership per provider keeps a clear answer to "who maintains this."
- Mixed authorship in one config is where silent drift starts.

## 3. Exceptions

- The user explicitly asks one agent to set up another's environment.
- Shared, agent-agnostic source (`.agents/`) that `sync_agent_configs.py`
  fans out - that is owned by the protocol, not a single runtime.
- Read-only reference: looking at another agent's config to copy a pattern
  into your own is fine; editing theirs is not.

---

## 4. Minimum Viable Statusline Contract

Every provider's statusline **must** surface these four primitives. Field
names are from the shared payload schema (same across providers):

| Primitive | Payload field | Meaning |
|-----------|--------------|---------|
| Model identity | `model.display_name` + `version` | What model is active |
| Effort mode | `effort.level` (optional - omit if unsupported) | How hard it's thinking |
| Quota fill | `rate_limits.five_hour.used_percentage` + `resets_at` | Runway remaining |
| Context fill | `context_window.used_percentage` | Session context consumed |

Everything else (token counts, cost, session name, inference slider, goal
banner) is provider-specific enhancement. Providers may add or omit these
freely. The four primitives are the floor.

---

## 5. Strict Separation of Provider State (No Cross-Reading)

Each agentic provider must stick strictly to its own dedicated configuration directory:
- Claude Code: `~/.claude/`
- Gemini / Antigravity: `~/.gemini/` or `~/.antigravity/`
- Future models: `.codex`, etc.

> [!CAUTION]
> **EXECUTIVE ORDER: STRICT BOUNDARY ENFORCEMENT**
> Under no circumstances whatsoever may any Gemini/Antigravity agent, model, or custom script attempt to read from or write to the `~/.claude/` directory. Similarly, no Claude agent or script may read from or write to the `~/.gemini/` or `~/.antigravity/` directories.
>
> This cross-reading restriction is an absolute boundary. Agents/scripts must only operate within their own provider-specific namespaces (`~/.claude/` vs `~/.gemini/` / `~/.antigravity/`) or the shared repository directory (`.agents/`). Any cross-reading (like the legacy behavior of the Antigravity statusline reading `~/.claude/goal-state.json`) is a severe protocol violation.

Any shared configuration or state must be stored locally in the workspace under `.agents/` or handled via explicit, provider-isolated sidecars.

---

## 6. Additive and Universal Compatibility

All rules, skills, commands, playbooks, and configurations stored in `.agents/` (the shared source of truth) must be designed to be natively compatible with all supported platform runtimes (e.g. Claude Code, Gemini/Antigravity).

- **No Platform-Specific Exclusions:** No shared config or instruction should require manual platform-specific exclusion blocks (e.g., "if Claude do this, but if Gemini skip").
- **Dynamic Parameterization:** If a path, setting, or logic differs between platforms, it must be resolved dynamically at runtime (for example, checking active model metadata or environment variables to pick the appropriate directory namespace `~/.claude/` vs `~/.antigravity/`).
- **Additive Configuration:** The configurations, guidelines, and rules must remain purely additive, ensuring that neither provider is restricted or conflicted by files shared in the `.agents/` repository.
