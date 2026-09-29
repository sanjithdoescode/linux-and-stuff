# Workspace Session Snapshot & Restore (`wsave` / `wrestore`)

## Purpose
Snapshot your current Hyprland window layout to a JSON file and restore it later — re-launching each application in its saved workspace. A lightweight session manager for Hyprland.

## Usage

```bash
wsave                  # Save current layout as "default"
wsave coding           # Save with a custom name
wsave meeting

wrestore               # Restore "default" session
wrestore coding        # Restore a named session
```

## What Gets Saved

For each open window: `class`, `title` (first 60 chars), `workspace name`, `at` (position), `size`.

Session files are stored in `~/.local/state/omarchy/sessions/<name>.json`.

## Launcher Configuration

`wrestore` maps window class names to launch commands via:
[`~/.config/omarchy/session-launchers.json`](../dotfiles/.config/omarchy/session-launchers.json)

```json
{
  "firefox": "firefox",
  "nvim": "ghostty -e nvim",
  "sp-lazygit": "ghostty --class=sp-lazygit -e lazygit"
}
```

If a class is not in the map, the class name itself is used as the command (works for most CLI apps).

## Limitations

- Window **positions within tiling layouts** are not exactly restored (Hyprland dispatches windows to workspaces, not pixel positions).
- The feature targets "re-open apps in correct workspaces" rather than pixel-perfect layout restoration.
- Apps that require user input to start (e.g., SSH tunnels) won't auto-restore fully.

## Where It Lives
- `wsave` / `wrestore` — added to `dotfiles/.zshrc` Section 17
- [`dotfiles/.config/omarchy/session-launchers.json`](../dotfiles/.config/omarchy/session-launchers.json)

## Dependencies
- `hyprctl`, `jq`
