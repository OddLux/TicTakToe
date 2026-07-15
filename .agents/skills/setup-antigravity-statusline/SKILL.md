---
name: setup-antigravity-statusline
description: >
  Generate and activate Antigravity CLI statusline presets (minimal / standard /
  verbose). Writes a Python script to ~/.antigravity/statusline.py and a thin bash
  wrapper to ~/.antigravity/statusline.sh, then wires both into ~/.antigravity/settings.json.
  Requires Python 3.9+ in PATH. No jq needed.
  Trigger: /setup-antigravity-statusline invoked.
version: 1.0.1
status: experimental
runs: 0
last-run: never
upgrade-conditions:
  - "Antigravity statusline payload schema changes"
  - "new preset tiers added"
---

# Statusline Presets (Antigravity)

Configure the Antigravity CLI's status line with a named preset. Three presets ship
out of the box:

| Preset | What it shows |
|--------|---------------|
| `minimal` | Model name + context % -- one line, always safe |
| `standard` | Model, effort, session name, context bar, reset countdown |
| `verbose` | Full professional bar: 5h heat-gradient bar + quota percentages + countdown + session cost telemetry |

## Usage

```
/setup-antigravity-statusline [minimal|standard|verbose]
```

---

## Steps

### 1. Resolve preset

- If the user provided a preset name, use it.
- If not, ask: "Which preset -- minimal, standard, or verbose?"
- Reject any unrecognized name and list the valid options.

### 2. Write ~/.antigravity/statusline.py

Write the Python script for the chosen preset to `~/.antigravity/statusline.py`.
Overwrite any existing file.

**minimal**

```python
import sys, json
sys.stdout.reconfigure(encoding="utf-8")
try:
    data = json.load(sys.stdin)
except Exception:
    print("[?] agy v? {used}%")
    sys.exit(0)
model = (data.get("model") or {}).get("display_name") or "?"
version = data.get("version") or "?"
used = int((data.get("context_window") or {}).get("used_percentage") or 0)
print(f"[{model}] agy v{version} {used}% ctx")
```

**standard**

```python
import sys, json, time
sys.stdout.reconfigure(encoding="utf-8")

RED = "\033[31m"
ORG = "\033[38;5;208m"
YEL = "\033[33m"
GRN = "\033[32m"
CYN = "\033[36m"
MAG = "\033[35m"
PRP = "\033[38;5;93m"   # royal purple
GLD = "\033[38;5;214m"  # gold/amber
DIM = "\033[2m"
RST = "\033[0m"

MODEL_COLORS = {
    "flash":  YEL,
    "pro":    CYN,
    "ultra":  PRP,
    "haiku":  YEL,
    "sonnet": CYN,
    "opus":   PRP,
    "fable":  GLD,
}
EFFORT_COLORS = {
    "low":    GRN,
    "medium": YEL,
    "high":   MAG,
}

try:
    data = json.load(sys.stdin)
except Exception:
    print("[?][?][effort:?][v?]")
    print("░░░░░░░░  quota:?  reset:?")
    sys.exit(0)

cwd = (data.get("cwd") or "").replace("\\", "/")
if len(cwd) > 60:
    cwd = "..." + cwd[-57:]

model_id = ((data.get("model") or {}).get("id") or "").lower()
model_raw = (data.get("model") or {}).get("display_name") or "?"
model_disp = model_raw.lower().replace(" ", "-")
effort_raw = (data.get("effort") or {}).get("level") or "?"
version = data.get("version") or "?"
session = data.get("session_name") or ""
if len(session) > 50:
    session = session[:47] + "..."

cwd_token = f"{DIM}{YEL}[{cwd}]{RST}"
model_color = RST
for key, color in MODEL_COLORS.items():
    if key in model_id or key in model_disp:
        model_color = color
        break
model_token = f"{model_color}[{model_disp}]{RST}"
effort_color = EFFORT_COLORS.get(effort_raw, RST)
effort_token = f"{effort_color}[effort:{effort_raw}]{RST}"
version_token = f"[v{version}]"

line1 = cwd_token + model_token + effort_token + version_token
if session:
    line1 += f"  {session}"
print(line1)

# Line 2: hero metrics
ctx_pct = int((data.get("context_window") or {}).get("used_percentage") or 0)
rate = data.get("rate_limits") or {}
five = rate.get("five_hour") or {}
five_pct = five.get("used_percentage")

five_pct_f = float(five_pct) if five_pct is not None else None
bar_pct = int(five_pct_f) if five_pct_f is not None else ctx_pct
if bar_pct >= 80:
    bar_color = RED
elif bar_pct >= 70:
    bar_color = ORG
elif bar_pct >= 60:
    bar_color = YEL
else:
    bar_color = GRN

filled = bar_pct * 12 // 100
bar_str = f"{bar_color}{'█' * filled}{'░' * (12 - filled)}{RST}"

quota_val = f"{five_pct_f:.1f}" if five_pct_f is not None else str(ctx_pct)
quota_label = f"5h-quota:{quota_val}%"
quota_str = f"{bar_color}{quota_label}{RST}" if bar_pct >= 60 else quota_label

resets_at = five.get("resets_at")
countdown = "?"
if resets_at:
    rem = int(resets_at) - int(time.time())
    if rem > 0:
        hrs, mins_r = rem // 3600, (rem % 3600) // 60
        countdown = f"{hrs}h{mins_r:02d}m" if hrs else f"{mins_r}m"
    else:
        countdown = "now"

reset_str = f"{DIM}reset:{countdown}{RST}"
print(f"{bar_str}  {quota_str}  {reset_str}")
```

**verbose**

This preset uses the full statusline renderer template containing USD cost sidecar support. See `dotfiles/.antigravity/statusline.py` in the repository for details.

### 3. Write ~/.antigravity/statusline.sh

Write a thin bash wrapper that pipes stdin to the Python script.

```bash
#!/bin/bash
python "$HOME/.antigravity/statusline.py"
```

Make it executable: `chmod +x ~/.antigravity/statusline.sh`.

### 4. Create ~/.antigravity/data/

Ensure `~/.antigravity/data/` directory exists.

### 5. Update ~/.gemini/antigravity-cli/settings.json

Read the settings file; if it does not exist, start with `{}`. Merge the `statusLine` key:

```json
"statusLine": {
  "type": "command",
  "command": "bash -c 'I=$(cat);D=$HOME/.antigravity/data;mkdir -p \"$D\" 2>/dev/null;T=\"$D/.sl-$$\";printf \"%s\" \"$I\">\"$T\"&&mv -f \"$T\" \"$D/antigravity-statusline.json\" 2>/dev/null||rm -f \"$T\" 2>/dev/null;printf \"%s\" \"$I\"' | bash ~/.antigravity/statusline.sh",
  "padding": 2,
  "refreshInterval": 5
}
```

Also, update the `hooks` section of `settings.json` to register the Stop hook running `session_cost.py` (which must be copied to `~/.antigravity/session_cost.py` from the repository):

```json
"hooks": {
  "Stop": [
    {
      "type": "command",
      "command": "python ~/.antigravity/session_cost.py --platform antigravity"
    }
  ]
}
```

### 6. Verify

Print the updated configuration block for confirmation.

### 7. Prompt restart

Always end with this message, verbatim:

> **Restart Antigravity CLI now** for the status line to take effect.
