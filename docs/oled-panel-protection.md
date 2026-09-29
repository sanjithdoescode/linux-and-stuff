# OLED Panel Health & Static-Display Monitor (`panel-health`)

## Purpose
Helps protect OLED/AMOLED laptop screens from pixel burn-in by monitoring workspace residency duration and reporting burn-in risk directly in the terminal based on the activity history captured by the `hyprd` IPC event daemon.

## Usage

```bash
panel-health
```

Output:
```text
📺 Panel Health Report
  Current workspace : 3
  Static for        : 45m 12s
  Workspace switches: 18 (session total)
  Burn-in risk      : Medium 🟡 — Consider switching workspace
```

## Risk Thresholds

| Duration on Current Workspace | Risk Level | Recommendation |
|---|---|---|
| `< 1 hour` | **Low 🟢** | Safe; normal usage pattern |
| `1 – 2 hours` | **Medium 🟡** | Consider switching workspaces or taking a short break |
| `> 2 hours` | **High 🔴** | High static persistence; switch workspaces or blank the screen |

## Architecture

1. **Telemetry Provider**: The [`hyprd`](hyprland-ipc-daemon.md) IPC event daemon listens to Hyprland's `socket2` event stream. Whenever a workspace switch occurs, it logs `<timestamp> workspace <name>` to `~/.local/state/omarchy/workspace.log`.
2. **Analysis Function**: The `panel-health` Zsh function reads the latest timestamp and compares it to the current time, reporting the static dwell time and total switches.

## Files

| File | Purpose |
|---|---|
| `dotfiles/.zshrc` Section 18 | `panel-health` shell function |
| [`dotfiles/.local/bin/hyprd`](../dotfiles/.local/bin/hyprd) | Event daemon writing `workspace.log` |

## Dependencies
- `hyprd` daemon running (`systemctl --user start hyprd`)
