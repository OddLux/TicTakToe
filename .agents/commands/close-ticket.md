---
version: 1.0.0
---

Close a ticket. Usage: /close-ticket <id> "<one-line closing note>"

1. Open .tickets/open/<id>_*.md
2. Set Status: CLOSED, Closed: <today>
3. Write closing note to ## Closing notes section
4. Move file: git mv .tickets/open/<file> .tickets/closed/<file>
5. Update .tickets/BACKLOG.md: remove from Open table, add to Closed with date
6. Update CHANGELOG.md with the ticket's ## Changelog update entry
