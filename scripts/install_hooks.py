"""Configure git to use the repo's tracked hooks/ directory."""

import subprocess
import sys
from pathlib import Path


def main():
    repo_root = Path(__file__).parent.parent
    hooks_dir = repo_root / "hooks"

    if not hooks_dir.is_dir():
        print(f"Error: hooks/ directory not found at {hooks_dir}")
        sys.exit(1)

    result = subprocess.run(
        ["git", "config", "core.hooksPath", "hooks"],
        cwd=repo_root,
        capture_output=True,
        text=True,
    )

    if result.returncode != 0:
        print(f"Error: {result.stderr.strip()}")
        sys.exit(1)

    print("Git hooks configured: core.hooksPath = hooks")
    print("Active hooks:")
    for hook in sorted(hooks_dir.iterdir()):
        print(f"  {hook.name}")


if __name__ == "__main__":
    main()
