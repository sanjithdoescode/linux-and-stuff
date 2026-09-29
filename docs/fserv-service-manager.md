# `fserv` — Systemd Service Manager TUI

## Purpose
An interactive `fzf`-powered TUI for managing systemd **user** or **system** services. Replaces typing long `systemctl` and `journalctl` commands by surfacing services in a searchable fuzzy list with live status previews.

## Usage

```bash
fserv              # Manage user services (--user)
fserv --system     # Manage system services (escalates via sudo -n / run0)
```

### Keybindings (inside fzf)

| Key | Action |
|---|---|
| `Enter` | Open action picker (start/stop/restart/enable/disable/status/logs) |
| `Ctrl-L` | Stream last 80 log lines via pager |
| `Ctrl-X` | Stop service immediately |
| `Ctrl-/` | Toggle live status preview pane |

## Action Picker
If `gum` is installed, uses `gum choose` for a styled menu. Falls back to the `select` builtin.

## Where It Lives
- Added to `dotfiles/.zshrc` — Section 13

## Dependencies
- `systemctl` (always present on systemd systems)
- `fzf`
- `journalctl`
- Optional: `gum` (styled action picker), `bat` (syntax-highlighted log view)

## Privilege Escalation (--system mode)
Tries `sudo -n` first (passwordless sudo), then `run0` — matching the existing power plugin pattern.
