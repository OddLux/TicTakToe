# Version 1.0.0

# Ticket Updates and Notifications

Whenever a ticket is created, updated, closed, or moved (or any ticket operation is performed), the agent must append a Caveman Ultra summary at the very end of their response.

## Summary Requirements

- **Location:** At the very end of the final response, following all other explanations.
- **Style:** Caveman Ultra (terse, drop articles, drop fillers, drop conjunctions, use abbreviations, arrows for causality/relationship, short synonyms).
- **Contents:**
  - The ticket path (absolute or workspace-relative, e.g., `.tickets/open/dp-063_gemini-statusline-docs/TICKET.md`).
  - A summary of what updated or was operated on.

## Example

```
Ticket: .tickets/open/dp-063_gemini-statusline-docs/TICKET.md
Update: Add img ref -> antigravity-credits-statusline.png. Add statusline telemetry analysis -> description.
```
