---
name: triage-todos
description: >
  Two-tier TODO triage with feature creep protection. Scans inline
  # TODO: markers in code files AND TODO.md brain dumps. Runs a
  mandatory three-question gate before every ticket creation. Cross-checks
  each item against the decision ledger and CHANGELOG before the gate to
  surface contradictions and already-shipped work.
  Trigger: user says "triage the TODO", "clean up TODO.md", "triage todos",
  "convert TODO to tickets", "run triage-todos", "/triage-todos".
version: 1.0.0
status: experimental
runs: 0
last-run: never
upgrade-conditions:
  - "TODO.md format conventions change"
  - "new triage verdict types added"
---

# Triage TODOs

Two-tier TODO triage: scans inline `# TODO:` code markers and `TODO.md`
brain dumps, then shepherds each item through a mandatory gate before
creating a ticket. Handles voice-transcribed brain dumps without
requiring the user to clean up prose first.

---

## Two Input Paths

### Path A - Inline `# TODO:` (fast-path)

Each inline marker is already scoped by location and usually atomic.

Flow: scan -> extract text -> decision-ledger cross-check -> gate -> ticket

### Path B - TODO.md brain dump (slow-path)

Conversational or voice-transcribed prose. May need filler stripped and
ideas split before the gate.

Flow: read file -> parse entries -> strip filler -> decision-ledger
cross-check -> gate -> ticket

Both paths run the same gate. The gate is non-optional.

---

## Instructions

### 1. Determine scope

If the user provides a path, scan that directory/file for inline `# TODO:`
markers (Path A). If no path is given, default to reading `TODO.md` in
the repo root (Path B). Both paths can run in the same session if asked.

### 2. Load context sources

Before processing any entries, read:

- `.agents/knowledge/decision-ledger.md` - prior decisions and rejected
  approaches
- `CHANGELOG.md` - shipped features and fixes
- `.tickets/BACKLOG.md` - open and closed ticket titles

Skip any file that does not exist. Do not error out.

### 3A. Path A - Scan inline TODOs

Use the Cavecrew investigator subagent to find all inline TODO markers
across the target path. Patterns: `# TODO:`, `# TODO`, `// TODO:`,
`-- TODO:`, `/* TODO:`. Return format: `file:line - text`.

For each result:
- Extract the raw TODO text (strip comment syntax).
- Note the file and line for the ticket's Area field.
- Run decision-ledger cross-check (step 4).
- Run the feature creep gate (step 5).

Each inline `# TODO:` maps to exactly one proposed ticket. No bundling.

### 3B. Path B - Parse TODO.md

Read the full file. If it contains only the boilerplate header (no real
entries below the `---` separator), report "TODO.md is empty." and stop.

For each entry (checklist item, `##` section, or blank-line-separated
paragraph):

1. **Extract the core ask**: identify the one thing being requested.
   Strip filler words, hedging, and conversational rambling. If the
   entry is voice-transcribed, find the concrete idea buried in it.
   Present the distilled version: "I read this as: [X]. Correct?"
2. **Split if needed**: if one entry contains multiple unrelated ideas,
   split into separate items and treat each independently.
3. Run decision-ledger cross-check (step 4).
4. Run the feature creep gate (step 5).

### 4. Decision-ledger cross-check

Before the gate, search `decision-ledger.md` and `CHANGELOG.md` for
keywords from the item's core ask.

**Conflicting decision found** (idea was rejected or an alternative
was explicitly ruled out):

```
!! CONFLICT DETECTED
   Item: "[distilled ask]"
   Decision ledger [YYYY-MM-DD]: "[relevant excerpt]"
   Options:
     A) Drop this item - decision still stands
     B) Proceed to gate - decision is stale or being deliberately overridden
```

Wait for user choice. If B, note the override in Implementation notes.
If A, remove the entry from TODO.md and move on.

**Item appears already shipped** (found in CHANGELOG):

```
!! ALREADY SHIPPED
   Item: "[distilled ask]"
   CHANGELOG: "[relevant entry]"
   Drop this item? (y/n)
```

**Matching open ticket exists** (found in BACKLOG.md):

```
!! DUPLICATE
   Item: "[distilled ask]"
   Open ticket: [dp-NNN] - [title]
   Drop this item? (y/n)
```

If none of the above apply, proceed to the gate.

### 5. Feature creep gate

Run these three questions for every item before creating a ticket.
Non-optional - do not skip even for items that "look simple".

**Q1 - What does done look like?**
Draft acceptance criteria from the item's core ask and present:

> "Done looks like: [draft criteria]. Does that capture it?"

Accept or refine. If the user's answer expands scope, flag it:

> "That sounds broader than the original item. Track the expansion as a
> separate ticket, or does this replace the original?"

**Q2 - Coupling check**
Ask: "Can this ship without touching more than 2 systems or modules?"

If yes: proceed.
If no: suggest splitting.

> "This touches [X, Y, Z]. Consider splitting: [suggested split]. Or
> proceed as one broader ticket?"

**Q3 - MVP pressure**
Ask: "What's the smallest version you'd actually ship?"

- Same as original: proceed.
- Subset: offer to scope the ticket to the MVP and create a follow-up.
- Expands scope: flag it and ask to pare down.

After all three questions, present the proposed ticket:

```
Proposed: dp-NNN
  Title: [title]
  Area: [area]
  Criteria:
    - [criterion from Q1]
    - [criterion 2]
  Notes: [Q2 coupling note if relevant] [Q3 MVP note if relevant]

Create? (y/n/edit)
```

### 6. Create confirmed tickets

For each item confirmed:

1. Derive slug: lowercase hyphens, max 5 words.
2. Determine next ID from BACKLOG.md.
3. Copy `.tickets/TICKET_TEMPLATE.md` to `.tickets/open/<id>_<slug>.md`.
4. Fill all header fields (Status: OPEN, Area, Branch, Opened: today).
5. Write Description, Acceptance criteria (from Q1), Implementation notes
   (Q2 coupling note, Q3 MVP note, any decision-ledger override note).
6. Append row to `.tickets/BACKLOG.md` `## Open` table.

### 7. Clean up source

After ticket creation, offer to remove the source item:

- **Path A**: "Mark `file:line` TODO as handled? I'll add a
  `# TICKET: dp-NNN` comment or remove the line."
- **Path B**: Remove the entry from `TODO.md` immediately after
  ticket creation. No separate cleanup pass.

### 8. Commit

Run `/commit-changes` after all items are processed.
Suggested message:

```
docs(tickets): triage TODOs - add N tickets, remove M items
```

---

## Scope exclusions (dp-010)

- Auto-creating tickets without the gate dialog.
- Syncing to external systems (Linear, GitHub Issues).
- Modifying TODO.md items without confirmation.

---

## Edge Cases

**All items dropped/discarded:**
Report result. Remove discarded entries from TODO.md. Commit cleanup
even if no tickets were created.

**Entry is entirely filler with no extractable core ask:**
Discard. Report: "Could not extract a core ask from: [text]."
Offer to keep or discard.

**User says "skip the gate":**
Q1 (acceptance criteria) is non-negotiable - at least one verifiable
criterion required. Q2 and Q3 can be short-circuited if user explicitly
accepts the defaults.

**Decision ledger entry is old:**
Show the date in the CONFLICT block. User may override; record in
Implementation notes.
