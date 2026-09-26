# TODO

Brain dump. Ideas and rough thoughts - not commitments.
Agent: review this when asked and offer to convert items to tickets or execute
small ones directly.

---

The release gate in AGENTS.md (block feature/bugfix commits once [Unreleased]
holds 5+ entries, auto-run /make-new-build after each qualifying master
commit) can't be followed in this repo. There's no pyproject.toml, so
`uv version --bump` has nothing to bump. There are no tags. [Unreleased] has
grown to 13 entries across every plugin round without a release. Either give
the Lua plugin a version source (a `# Version` header in TicTacToe.lua or a
VERSION file) and adapt make-new-build to it, or relax the gate for this
project. Until then, every commit here quietly skips the rule.
