---
trigger: always_on
---

# Version 1.6.0

# Agent Coding Standards - Python 3.9+

Consolidated from PEP 8, Google Python Style, Black (88 chars), and the
internal coding-standards repo. Formatted with **ruff**.

---

## 1. Formatting & Line Length

- **Line length: 88 characters** - hard ceiling for all code, docstrings, comments.
- **Indentation: 4 spaces.** No tabs.
- ruff handles the mechanical stuff. Configure once, let it run on save.

```toml
[tool.ruff]
line-length = 88
target-version = "py39"

[tool.ruff.lint]
select = ["E", "F", "W", "I", "UP", "B", "SIM"]

[tool.ruff.lint.isort]
known-first-party = ["your_package"]
```

The `"UP"` ruleset (pyupgrade) auto-modernises legacy patterns to Python 3.9+
syntax (e.g., `typing.List` -> `list`, old-style string formatting, etc.).

---

## 2. Naming Conventions

**Everything is snake_case unless the table below says otherwise.**

| What                  | Convention         | Example                      |
|-----------------------|--------------------|------------------------------|
| Modules / packages    | `snake_case`       | `asset_loader`               |
| Classes               | `UpperCamelCase`   | `AssetLoader`                |
| Functions / methods   | `snake_case`       | `load_asset`                 |
| Variables / locals    | `snake_case`       | `frame_count`, `idx`, `cfg`  |
| Constants             | `ALL_CAPS`         | `MAX_RETRIES`, `DEFAULT_FPS` |
| "Private" / internal  | `_leading_under`   | `_cache`, `_load_raw`        |
| Dunder                | `__dunder__`       | `__init__`, `__repr__`       |

### Minimum 3-letter identifiers

All variable names - locals, globals, loop iterables, parameters - must be
**at least 3 characters**. Keeps names greppable without over-explaining.

```python
# Good                                  # Bad
for idx in range(count): ...            for i in range(n): ...
result = process(cfg, obj)              x = do_thing()
items = [itr.name for itr in coll]      for a in items: ...
```

Only exception: universally understood constants like `PI`. When in doubt,
spell it out.

Don't alias imports with underscores to "hide" them - it hurts readability.
`import os as _os` -> just `import os`.

### Spelling

Use **American English** for all identifiers: `color` not `colour`, `center`
not `centre`, `serialize` not `serialise`.

---

## 3. Imports

Order: **stdlib -> third-party -> local**. Alphabetical within each group.

```python
import logging
import sys
from pathlib import Path

import click
import requests

from mypackage import utils
from mypackage._core import AssetLoader
```

Use **relative imports** within a package, **absolute** for everything else. If
a relative path goes deeper than ~3 levels, flatten your package structure.

```python
from . import _helpers          # relative, intra-package
from mypackage.utils import sanitize  # absolute, external
```

### Public API via `__all__`

Declare your public surface explicitly. Internal modules get `_underscore`;
objects inside them don't need one - the module name shields them.

```python
# mypackage/__init__.py
from ._core import useful_function, great_tool

__all__ = ("useful_function", "great_tool")
```

---

## 4. Type Hints - Minimal by Default

**Avoid type hints unless they genuinely improve readability.** Most functions
are clear enough from their docstring and naming. Annotating everyday `list`,
`dict`, `str`, `int` parameters adds visual noise without meaningful benefit.

Hints are warranted **only** when:

- A custom class, dataclass, Protocol, or TypedDict is involved.
- A factory returns a non-obvious type (abstract base class or a union).
- A public API boundary where callers won't see the source.

```python
# No hints needed
def load_config(path):
    """Load and return a config dict from the given path."""
    ...

# Hints warranted - custom structure, non-obvious return
@dataclass
class RenderConfig:
    width: int
    height: int
    fps: int

def create_renderer(config: RenderConfig) -> "Renderer":
    """Build a Renderer from the given config."""
    ...
```

**Never** import from `typing` just to annotate built-in generics. Since we
target 3.9+, `list[int]` is valid syntax - but that doesn't mean sprinkle it
everywhere. If a hint isn't pulling its weight, delete it.

---

## 5. Python 3.9+ Idioms

These are **standard practice** for any new code targeting 3.9+. Use them.

### Dict merge operators (PEP 584)

Use `|` to merge dicts and `|=` to update in place. Cleaner than
`{**a, **b}` or `a.update(b)`.

```python
defaults = {"fps": 24, "width": 1920}
overrides = {"fps": 30, "format": "exr"}

config = defaults | overrides   # merge into a new dict
defaults |= overrides           # update in place
```

### `str.removeprefix()` / `str.removesuffix()` (PEP 616)

```python
stem = filename.removesuffix(".exr")   # good - 3.9+
stem = filename.rstrip(".exr")         # bad - silently wrong if chars overlap
```

### `functools.cache` (3.9+)

```python
from functools import cache

@cache
def expensive_lookup(asset_id):
    """Fetch asset metadata from the database."""
    ...
```

Use `@lru_cache(maxsize=N)` when you need a bounded cache.

### `zoneinfo` - stdlib timezone handling (PEP 615)

```python
from datetime import datetime
from zoneinfo import ZoneInfo

now_london = datetime.now(tz=ZoneInfo("Europe/London"))
now_utc = datetime.now(tz=ZoneInfo("UTC"))
```

### Walrus operator `:=` (PEP 572, 3.8+)

Use when it reduces duplication in a condition - typically `while` loops and
`if` checks that would otherwise need a throwaway variable above the block.

```python
if (match := pattern.search(line)) is not None:
    process(match.group(1))

while (chunk := stream.read(8192)):
    buffer.append(chunk)
```

---

## 6. String Quotes

Use **double quotes** for all strings.

```python
message = "This isn't a problem."   # good
message = 'This isn\'t very nice.'  # bad
```

---

## 7. Docstrings

Every **public** module, class, function, and method gets a docstring. Internal
helpers (`_prefixed`) get one if they do anything non-obvious.

**Google-style** sections. First line: single imperative-mood sentence. More
detail after a blank line.

```python
def find_missing_frames(sequence, expected_range):
    """Return frame indices missing from the given sequence.

    Args:
        sequence: List of frame numbers that exist on disk.
        expected_range: Tuple of (start, end) defining the full range.

    Returns:
        Sorted list of integer frame indices not found in sequence.

    Raises:
        ValueError: If expected_range is empty or inverted.
    """
```

Document `__init__` arguments in `__init__`'s docstring, not the class
docstring - the class docstring describes *what the class is*. Properties get
a one-liner on the getter only, nothing on the setter.

---

## 8. Comments

Prefer docstrings over inline comments. Comments should explain *why*, not
*what*. No decorative rulers (`# -----`). Keep them actionable -
`# TODO(username): ...` is fine, `# this is fine` is not.

---

## 9. Constants

`ALL_CAPS`. Prefer **immutable types** - a mutated "constant" is a silent bug.

```python
# Good                                          # Bad
VALID_EXTENSIONS = ("exr", "png", "jpg")        VALID_EXTENSIONS = ["exr", "png", "jpg"]
PRIORITY_LEVELS = frozenset({1, 2, 3})          PRIORITY_LEVELS = {1, 2, 3}
```

---

## 10. Control Flow & Compound Statements

Don't squash branching onto one line. Comprehensions and simple ternaries are
fine; everything else gets proper indentation.

```python
names = [item.name for item in collection]       # fine
status = "active" if is_valid else "inactive"    # fine
if condition: do_thing()                         # bad
```

Only use comprehensions for **simple cases**. Each portion (mapping, `for`,
filter) must fit on one line. Use loops when things get more complicated.

### Long conditions -> extract a function

```python
def can_save(obj):
    """Return True if obj is valid, active, and has write permission."""
    return (
        obj.is_valid()
        and obj.is_active()
        and obj.has_permission("write")
    )

if can_save(obj):
    obj.save()
```

### Operator line breaks

Break **before** the operator when splitting expressions.

```python
total = (
    base_salary
    + bonus
    + overtime_pay
    - tax_deduction
)
```

---

## 11. Trailing Commas

Always add a trailing comma after the last item in multi-line lists, dicts,
function arguments, and function parameters. Keeps diffs clean - adding an
item changes one line, not two.

```python
# Good
FILES = [
    "setup.cfg",
    "tox.cfg",
]
initialize(
    FILES,
    debug=True,
)

# Bad - trailing commas on single-line constructs
FILES = ["setup.cfg", "tox.ini",]
initialize(FILES, debug=True,)
```

---

## 12. Assigning Empty Built-in Types

Use the short-form constructors. Avoids confusion if the named form has been
accidentally shadowed, and it's faster to read.

```python
my_list = []     # good
my_dict = {}     # good
my_list = list() # bad
my_dict = dict() # bad
```

---

## 13. Whitespace

Follow PEP 8. Spaces after colons and commas. No extra spaces inside brackets.
Operators get spaces on both sides.

```python
# Good
stalks = collection["Stalk"].all(
    collection["Stalk"]["job"] == "NSFL",
    collection["Stalk"]["status"] == "Approved",
)
theta = alpha * beta.calc() * sin(delta)

# Bad
stalks = collection[ "Stalk" ].all( collection[ "Stalk" ][ "job" ]== "NSFL" )
theta = alpha*beta.calc()*sin(delta)
```

---

## 14. Lambda Functions

Avoid lambdas. Bind functions to names - makes testing and stack traces easier
to follow. If the function is small, just `def` it.

```python
# Good
def double(val):
    """Return the value doubled."""
    return val * 2

results = map(double, items)

# Bad
results = map(lambda val: val * 2, items)
```

---

## 15. Logging

Use `logging`, never `print()` in core logic. Module-level `LOGGER`, `%s`-style
formatting (interpolation is skipped if the level is filtered out).

```python
import logging

LOGGER = logging.getLogger(__name__)


def process_batch(items):
    """Process a batch of items."""
    LOGGER.info("Processing %d items", len(items))
    for item in items:
        try:
            _handle(item)
        except Exception:
            LOGGER.exception("Failed to process item %s", item.id)
```

---

## 16. Error Handling

Fail fast. Raise specific, descriptive exceptions. Don't catch broad `Exception`
unless you're at a top-level boundary logging the full traceback.

```python
class AssetNotFoundError(Exception):
    """Raised when a requested asset doesn't exist on disk."""


def load_asset(asset_id):
    """Load an asset by ID."""
    path = _resolve_path(asset_id)
    if not path.exists():
        raise AssetNotFoundError(
            f"No asset found for id={asset_id}, expected at {path}"
        )
```

### Deprecation

Use `warnings.warn` - not comments or silent removals. Set `stacklevel=2` so
the warning points at the caller.

```python
import warnings

def old_function():
    """Do the old thing.

    .. deprecated:: Use ``new_function`` instead. Removed in v3.0.
    """
    warnings.warn(
        "old_function() is deprecated, use new_function() instead.",
        DeprecationWarning,
        stacklevel=2,
    )
```

---

## 17. File I/O & Paths

Always use `pathlib.Path`. Always specify encoding explicitly.

```python
from pathlib import Path

config_path = Path("/etc/myapp/config.yaml")
text = config_path.read_text(encoding="utf-8")
```

Use descriptive `prefix`/`suffix` on temp files and context managers for
automatic cleanup.

```python
import tempfile

with tempfile.TemporaryDirectory(
    prefix="myapp-render_",
    suffix="_output",
) as tmp_dir:
    ...
```

---

## 18. Subprocesses

Command list, not string. No `shell=True`, no `os.system`.

```python
import subprocess

result = subprocess.run(
    ["ffmpeg", "-i", input_path, "-c:v", "libx264", output_path],
    capture_output=True,
    text=True,
    check=True,
)
```

---

## 19. Testing

Use **pytest**. Use fixtures for setup/teardown.

```python
import pytest


def test_find_missing_frames():
    """Verify that gaps in a sequence are correctly identified."""
    result = find_missing_frames([1, 2, 4, 5], expected_range=(1, 5))
    assert result == [3]


def test_find_missing_frames_raises_on_invalid_range():
    """Verify that an inverted range raises ValueError."""
    with pytest.raises(ValueError):
        find_missing_frames([1, 2, 3], expected_range=(5, 1))
```

---

## 20. Versioning

All documents and code artifacts use **Semantic Versioning** (`MAJOR.MINOR.PATCH`).

| Bump   | When                                                        |
|--------|-------------------------------------------------------------|
| PATCH  | Typo fixes, minor corrections, small refinements           |
| MINOR  | New functionality, expanded instructions, new features     |
| MAJOR  | Structural overhaul, breaking changes, language expansions  |

Version number lives at the top of every document and in module/package
`__version__` where applicable. Treat a version bump as an intentional
publication - like a git tag.

---

## 21. Commit Messages

Single line, imperative mood, max **100 characters**. Use full-word conventional types.

```
feature: add retry logic to asset loader
bugfix: handle missing frames at sequence boundaries
docs: clarify deprecation policy in coding standards
chore: bump ruff to 0.3.1
```

`feature` and `bugfix` are deliberate full-word forms - not `feat`/`fix`.
