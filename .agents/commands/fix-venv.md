---
version: 1.0.0
---

Recover from Windows uv venv lock or permission errors. Usage: /fix-venv

1. Delete locked venv:
   Remove-Item -Path .venv -Recurse -Force
2. Recreate and sync:
   uv sync
