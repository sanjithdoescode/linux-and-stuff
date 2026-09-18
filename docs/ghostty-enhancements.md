# Ghostty Dropdown Terminal & Theme Sync

## Purpose
1. Adds a global Quake-style dropdown scratchpad terminal that can be summoned from anywhere with a single keyboard shortcut.
2. Fixes Omarchy dynamic theme synchronization by removing the hardcoded theme override.

## Implementation Details

### Configuration File Modified
* [~/.config/ghostty/config](file:///home/sanjith/.config/ghostty/config)

### Code Added & Modified
```ini
# Quick terminal (dropdown scratchpad toggled with Super + `)
keybind = global:super+grave_accent=toggle_quick_terminal
quick-terminal-position = top
quick-terminal-screen = main
quick-terminal-animation-duration = 0.2
quick-terminal-autohide = false
```

And removed/commented out hardcoded overrides:
```ini
# theme = Deep
# config-file = ?auto/theme.ghostty
```

Ghostty now directly inherits Omarchy's active theme:
```ini
config-file = ?"~/.local/state/omarchy/current/theme/ghostty.conf"
```

## Features

### 1. Dropdown Scratchpad Terminal (`Super + ` ` `)
* Press **`Super + ` ` `** (the backtick/grave key above Tab).
* Ghostty slides down from the top edge of your monitor as a Wayland layer surface.
* Run quick terminal tasks, scripts, or checks, then press **`Super + ` ` `** again to dismiss it without creating clutter on your Hyprland workspace.

### 2. Dynamic Omarchy Theme Sync
* When you switch themes using Omarchy:
  ```sh
  omarchy theme set <theme-name>
  ```
  Ghostty automatically updates its colors in real time to match the system palette (e.g. `Osaka Jade`, `Midnight`, `Catppuccin`, etc.).
