# Version 1.0.0

# No Automatic External Repo Cloning

External repositories must **never** be cloned, fetched, or added as
submodules automatically. This includes `git clone`, `git submodule add`,
`gh repo clone`, and any equivalent package-manager-level fetch that
pulls an external git tree into the workspace.

---

## 1. The Rule

- **Default: blocked.** Any `git clone <url>` or `git submodule add` is
  off-limits unless the user gives explicit, unambiguous instruction.
- **Double-confirm required.** If the user asks to clone something, confirm
  once with the URL and target path, wait for approval, then confirm a
  second time before executing. Two separate "yes" responses required.
- **Never auto-infer.** Do not clone a repo because a knowledge note
  references it, a skill mentions it, or it would be "useful context".
- **Mention is allowed.** Surfacing that a repo exists and what it contains
  is fine. Offering to clone it on demand is fine. Cloning without a direct
  ask is not.

---

## 2. Why

External repos are unverified surfaces. Even repos from known sources:

- May change content between when they were referenced and when they are
  pulled (supply chain concern).
- May contain hooks, CI scripts, or install files that execute on checkout.
- Consume disk space and become stale immediately.
- As git submodules, they silently pin a SHA and rot without visible signal.

The user can always run `git clone` locally in seconds. The cost of NOT
auto-cloning is near zero; the cost of an unreviewed clone landing in the
workspace can be high.

---

## 3. External Reference Pattern

When a project uses reference material from an external repo, store it as
a pointer in the knowledge base - not as a submodule or copied directory.

```markdown
# External Reference: <repo-name>

Source: <url>
Local mirror: <absolute-path-on-this-machine> (if cloned manually)
Last reviewed: YYYY-MM-DD

[Brief description of what this repo contains and why it is useful]
```

This makes the dependency visible without pulling it into the project tree.

---

## 4. Deny List Addition

`git clone` and `git submodule add` are added to the behavioral deny list.
They are not in `.claude/settings.json` (hard shell-level block) because
there are legitimate use cases - but they require explicit human instruction
every time.

| Command pattern | Status |
|-----------------|--------|
| `git clone *` | Blocked by default - double-confirm required |
| `git submodule add *` | Blocked by default - double-confirm required |
| `git submodule update --init *` | Blocked by default - double-confirm required |
| `gh repo clone *` | Blocked by default - double-confirm required |

---

## 5. Retroactive Cleanup

Any existing submodule in this repo should be deregistered and moved to
an external location (e.g. `E:\DEV_SPACE\_GITHUB\`) where the user
manages it independently. Do not re-add it.
