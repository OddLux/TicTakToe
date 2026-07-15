# Version 1.2.0

# Plain File Paths and Markdown Links

This rule governs how files are referenced in conversations, documentation, and agent outputs within this repository. It defines a Windows-compatible path convention and a markdown linking standard to optimize usability and copy-paste compatibility.

---

## 1. Windows Absolute Path Format (Standard)

Always format absolute paths using standard Windows forward-slash notation:
`E:/DEV_SPACE/dev-protocol/AGENTS.md` (Drive letter, colon, and forward slashes).

- **Never** use Unix mount style notation: `/e/DEV_SPACE/...`
- **Never** use backslashes: `E:\DEV_SPACE\...` (to avoid backslash escaping issues in code and strings).

---

## 2. Markdown Linking for `.md` Files

To allow the user to easily copy the absolute file paths of referenced documentation:
- When referencing any markdown (`.md`) file, **always** format the reference as a clickable markdown link using the absolute `file:///` URI scheme.
- Format: `[Link Text](file:///E:/DEV_SPACE/dev-protocol/path/to/file.md)`
- Link text must be descriptive (usually the filename and line range if applicable, e.g. [AGENTS.md](file:///E:/DEV_SPACE/dev-protocol/AGENTS.md)). Do not surround link text with backticks.

---

## 3. Plain Paths for Non-Markdown Files

- For non-markdown files (e.g., `.py`, `.json`, `.yaml`, `.toml`, `.sh`, `.txt`), use plain text absolute paths (e.g., `E:/DEV_SPACE/dev-protocol/scripts/sync_dotfiles.py`).
- Modern IDEs natively highlight these plain paths and make them clickable (via Ctrl+Click) without requiring custom markdown link syntax.

---

## 4. The Golden Rule of Pathing (Always On)

If a path is displayed or referenced in any agent output (including chat, handover packages, crumbs, retros, and session reports), **always display the full absolute path**. Never use relative paths or bare filenames.
