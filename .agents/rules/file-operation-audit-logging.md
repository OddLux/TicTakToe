# Version 1.0.0

# File Operation Audit Logging Rule

To maintain transparency and security without the overhead of interactive permission prompts, all agents must provide a brief, ultra-terse explanation (in Caveman-Ultra style) immediately before calling any tool that interacts with the filesystem.

## 1. Scope of Enforcement
This rule applies to the following filesystem operations:
- **Read Operations:** Reading file contents, searching/grepping, listing directories.
- **Write Operations:** Creating new files, overwriting existing files, deleting files.
- **Modification Operations:** Search-and-replace edits, regex replacements.
- **Terminal Execution:** Bash/PowerShell commands that have filesystem side-effects (e.g., git checkouts, compiling, formatting, running build tools).

## 2. Explanation Format
Before calling the tool, print a one-liner justification. Keep it under 5 words in Caveman-Ultra style:
`[operation] [target/context] -- [reason]`

### Examples:
- Before viewing a Python file:
  `Read config.py -- locate env defaults`
- Before editing a test file:
  `Edit test_auth.py -- fix assertion type mismatch`
- Before running a git commit command:
  `Git commit -- stage changes and bump version`
- Before listing a directory:
  `List open/ tickets -- check next ID`

## 3. Exceptions
Routine files and reads that are directly supporting a clearly stated goal (e.g., running `grep` inside a directory to locate a known symbol after the user asks for a fix) can omit the annotation if the context is obvious and clean. If in doubt, annotate.
