---
version: 1.1.0
---

Scaffold a new ticket. Usage: /new-ticket <id> "<title>" --area "<area>" [--idea]

1. Copy either `.tickets/TICKET_TEMPLATE.md` (default) or `.tickets/IDEA_TEMPLATE.md` (if `--idea` is specified) to `.tickets/open/<id>_<slug>.md`.
   ID format: dp-NNN. Slug: lowercase hyphens, max 5 words.
2. Fill all header fields (Status: OPEN for standard, IDEA for idea; Opened: today; Area; Branch: `ticket/<id>-<slug>` for standard, `-` for idea).
3. Append row to .tickets/BACKLOG.md ## Open table.
4. If this ticket was derived from a TODO.md entry, delete that entry from
   TODO.md immediately. Do not leave the graduated item behind.
