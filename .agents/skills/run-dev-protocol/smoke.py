#!/usr/bin/env python3
"""Smoke test for dev-protocol CLI.

Run from repo root:
    uv run python .agents/skills/run-dev-protocol/smoke.py
"""
import subprocess
import sys
import tempfile
from pathlib import Path

REPO_ROOT = Path(__file__).parents[3]
PASS_COUNT = 0
FAIL_COUNT = 0


def run(args, cwd=None):
    result = subprocess.run(
        args, cwd=str(cwd or REPO_ROOT), capture_output=True, text=True
    )
    return result.stdout + result.stderr, result.returncode


def ok(name):
    global PASS_COUNT
    PASS_COUNT += 1
    print(f"  PASS  {name}")


def fail(name, detail=""):
    global FAIL_COUNT
    FAIL_COUNT += 1
    print(f"  FAIL  {name}" + (f"  ({detail})" if detail else ""))


def check(name, output, expected):
    if expected in output:
        ok(name)
    else:
        fail(name, f"expected {expected!r}")
        print(f"        got: {output[:300]!r}")


def section(title):
    print(f"\n-- {title}")


section("Basic invocation")
out, _ = run(["uv", "run", "dev-protocol", "--help"])
check("--help", out, "initialize and manage agentic development environments")

out, _ = run(["uv", "run", "dev-protocol", "--version"])
check("--version", out, "dev-protocol, version")

out, _ = run(["uv", "run", "dev-protocol", "init", "--help"])
check("init --help: --dry-run flag", out, "--dry-run")
check("init --help: --claude flag", out, "--claude")
check("init --help: --profile flag", out, "--profile")

out, _ = run(["uv", "run", "dev-protocol", "claude-sync", "--help"])
check("claude-sync --help", out, "Mirror .agents/")

section("Guard rails")
out, _ = run(["uv", "run", "dev-protocol", "init", "--dry-run"])
check("own-repo guard", out, "Cannot initialize dev-protocol inside its own repository")

with tempfile.TemporaryDirectory() as tmp:
    out, _ = run(
        ["uv", "run", "--project", str(REPO_ROOT), "dev-protocol", "init", "--dry-run"],
        cwd=tmp,
    )
    check("non-git dir guard", out, "Not a git repository root")

with tempfile.TemporaryDirectory() as tmp:
    subprocess.run(["git", "init", "-q", tmp], check=True)
    out, _ = run(
        ["uv", "run", "--project", str(REPO_ROOT), "dev-protocol", "claude-sync"],
        cwd=tmp,
    )
    check("claude-sync no-.agents guard", out, "No .agents/ directory found")

section("init --dry-run core output")
with tempfile.TemporaryDirectory() as tmp:
    subprocess.run(["git", "init", "-q", tmp], check=True)
    out, _ = run(
        ["uv", "run", "--project", str(REPO_ROOT), "dev-protocol", "init", "--dry-run"],
        cwd=tmp,
    )
    check("dry-run header", out, "Dry run -- no files will be written")
    check("rules stamped", out, "coding-behavior.md")
    check("skills stamped", out, "commit-changes")
    check("summary footer", out, "Initialized dev-protocol in")

section("init --claude flag")
with tempfile.TemporaryDirectory() as tmp:
    subprocess.run(["git", "init", "-q", tmp], check=True)
    out, _ = run(
        [
            "uv", "run", "--project", str(REPO_ROOT),
            "dev-protocol", "init", "--claude", "--dry-run",
        ],
        cwd=tmp,
    )
    check("--claude adds .claude/ targets", out, ".claude")
    check("--claude adds CLAUDE.md", out, "CLAUDE.md")

section("init --profile dneg flag")
with tempfile.TemporaryDirectory() as tmp:
    subprocess.run(["git", "init", "-q", tmp], check=True)
    out, _ = run(
        [
            "uv", "run", "--project", str(REPO_ROOT),
            "dev-protocol", "init", "--profile", "dneg", "--dry-run",
        ],
        cwd=tmp,
    )
    check("--profile dneg stamps ptsup agent", out, "dneg-ptsup-investigator")

section("claude-sync round-trip")
with tempfile.TemporaryDirectory() as tmp:
    subprocess.run(["git", "init", "-q", tmp], check=True)
    run(
        ["uv", "run", "--project", str(REPO_ROOT), "dev-protocol", "init", "--claude"],
        cwd=tmp,
    )
    out, _ = run(
        [
            "uv", "run", "--project", str(REPO_ROOT),
            "dev-protocol", "claude-sync", "--dry-run",
        ],
        cwd=tmp,
    )
    check("claude-sync reports sync count", out, "Synced .agents/ -> .claude/")
    check("idempotent: all UNCHANGED after fresh init", out, "UNCHANGED")

print(f"\n{'='*40}")
print(f"Results: {PASS_COUNT} passed, {FAIL_COUNT} failed")
sys.exit(0 if FAIL_COUNT == 0 else 1)
