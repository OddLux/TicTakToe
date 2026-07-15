# Version 1.0.0

# Commit Receipt

After every git commit - any commit, any skill, any context - print:

```
▸ {hash}  {subject}
  {/absolute/path/to/file}
  {/absolute/path/to/file}
  ... N more files
```

Rules:

- **Absolute paths only.** User can Ctrl+click to open in VS Code.
- List all files when total <= 10.
- When total > 10: list first 10, then `  ... N more files` (N = remainder).
- Subject truncated at 72 chars + `...` if longer.
- `... N more files` line only appears when total > 10.
- **Never skip.** Not for chore, release, dev-bump, or any other commit type.

Commands to build the receipt:

```bash
# hash + subject
git log -1 --format="%h %s"

# absolute file paths
git show --name-only --format="" HEAD | while read f; do echo "$(git rev-parse --show-toplevel)/$f"; done
```
