# Hyprland IPC Event Daemon (`hyprd`)

## Purpose
A persistent systemd user service that connects to Hyprland's `socket2` IPC event stream and reacts to real-time compositor events — no polling, event-driven only.

## Events Handled

| Event | Action |
|---|---|
| `monitoradded` | Desktop notification: "Monitor Connected" |
| `monitorremoved` | Desktop notification: "Monitor Disconnected" |
| `switch >> on >> Lid Switch` | If ≥1 external monitor present: disable `eDP-1` (laptop screen) via `hyprctl keyword` |
| `switch >> off >> Lid Switch` | Re-enable `eDP-1` at preferred resolution |
| `workspace` | Append `<epoch> workspace <name>` to `~/.local/state/omarchy/workspace.log` |

## Architecture

The daemon reads `$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock` via `socat`. Events are parsed with a `case` statement and dispatched in the background (`&`) to stay non-blocking.

The **workspace log** is consumed by the `panel-health` shell function to report OLED pixel burn-in risk.

## Files

| File | Purpose |
|---|---|
| [`dotfiles/.local/bin/hyprd`](../dotfiles/.local/bin/hyprd) | Main daemon script |
| [`dotfiles/.config/systemd/user/hyprd.service`](../dotfiles/.config/systemd/user/hyprd.service) | Systemd user service unit |
| [`dotfiles/.config/omarchy/hooks/post-boot.d/start-hyprd.hook`](../dotfiles/.config/omarchy/hooks/post-boot.d/start-hyprd.hook) | Omarchy boot hook to enable the service |

## Service Management

```bash
# Start immediately (without reboot)
systemctl --user start hyprd

# Enable for all future sessions
systemctl --user enable hyprd

# Check status and recent logs
systemctl --user status hyprd
journalctl --user -u hyprd -n 30

# Restart after config changes
systemctl --user restart hyprd
```

## Dependencies
- `socat` (`pacman -S socat`)
- `hyprctl` (bundled with Hyprland)
- `notify-send` (`libnotify` — usually pre-installed)
- `jq` (for external monitor count check)
