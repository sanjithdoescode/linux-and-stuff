# Google Antigravity Usage Plugin for Omarchy

Real-time Google Antigravity quota and rate limit monitor for the Omarchy status bar.

## Overview

This plugin displays real-time quota usage and limits for Google Antigravity (`agy`), neatly organized into the two primary model groups:
1. **Gemini Models** (Gemini 3.8 Flash, Gemini 3.7 Flash, Gemini 3.1 Pro)
   - **5-Hour Session Limit**: Percentage remaining/used, progress bar, and exact reset countdown.
   - **Weekly Limit**: Percentage remaining/used, progress bar, and reset countdown.
2. **Claude and GPT Models** (Claude Sonnet 4.6, Claude Opus 4.6, GPT-OSS 120B)
   - **5-Hour Session Limit**: Percentage remaining/used, progress bar, and reset countdown.
   - **Weekly Limit**: Percentage remaining/used, progress bar, and reset countdown.

## Features

- **Theme Native**: Integrates seamlessly with all Omarchy themes (Gruvbox, Nord, Catppuccin, etc.) via `qs.Commons.Color` and `qs.Commons.Style`.
- **Bar Widget**: Shows an icon and lowest remaining quota percentage (e.g. `84% 󰚩`).
- **Interactive Panel**:
  - `Left Click`: Toggle usage dashboard panel.
  - `Right Click`: Launch `agy` terminal CLI.
  - `Middle Click`: Force refresh quota.
- **Keyboard Navigation**:
  - `r` / `R` or `Enter`: Refresh quota.
  - `Esc`: Close panel.
  - `Tab`: Switch to neighboring bar panel.
- **IPC Support**: `omarchy-shell sanjith.antigravity <open|close|toggle|refresh>`.
- **Automatic Token Refresh**: Seamlessly refreshes Google OAuth tokens and stays in sync with `secret-tool` / system keyring.

## Installation & Configuration

The plugin is located at:
`~/.config/omarchy/plugins/sanjith.antigravity/`

To add it to your Omarchy bar layout, add `{"id": "sanjith.antigravity"}` to the `bar.layout.right` section in `~/.config/omarchy/shell.json`.
