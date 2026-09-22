# Google Antigravity Usage Omarchy Plugin

## Purpose
Provides a native, theme-integrated **Omarchy bar widget and dashboard panel** for monitoring real-time **Google Antigravity (`agy`)** usage, quotas, and rolling rate limits.

The plugin provides clear, at-a-glance visibility into the two primary model groups and both of their distinct limit windows:
1. **Gemini Models** (`Gemini 3.8 Flash`, `Gemini 3.7 Flash`, `Gemini 3.1 Pro`)
   - **5-Hour Session Window**: Rate limit meter, remaining vs used percentage, and reset countdown.
   - **Weekly Rolling Window**: Rate limit meter, remaining vs used percentage, and reset countdown.
2. **Claude and GPT Models** (`Claude Sonnet 4.6`, `Claude Opus 4.6`, `GPT-OSS 120B`)
   - **5-Hour Session Window**: Rate limit meter, remaining vs used percentage, and reset countdown.
   - **Weekly Rolling Window**: Rate limit meter, remaining vs used percentage, and reset countdown.

---

## Architecture & Implementation

### Files Created
* [`dotfiles/.config/omarchy/plugins/sanjith.antigravity/manifest.json`](file:///home/sanjith/Projects/omarchy_changes/dotfiles/.config/omarchy/plugins/sanjith.antigravity/manifest.json) — Plugin metadata, schema, and Omarchy bar-widget registration.
* [`dotfiles/.config/omarchy/plugins/sanjith.antigravity/Panel.qml`](file:///home/sanjith/Projects/omarchy_changes/dotfiles/.config/omarchy/plugins/sanjith.antigravity/Panel.qml) — Quickshell QML panel with animated meters, keyboard controls, and theme integration.
* [`dotfiles/.config/omarchy/plugins/sanjith.antigravity/get_usage.py`](file:///home/sanjith/Projects/omarchy_changes/dotfiles/.config/omarchy/plugins/sanjith.antigravity/get_usage.py) — Live API scraper, OAuth token auto-refresher, and local SQLite session aggregator.
* [`dotfiles/.config/omarchy/plugins/sanjith.antigravity/status.sh`](file:///home/sanjith/Projects/omarchy_changes/dotfiles/.config/omarchy/plugins/sanjith.antigravity/status.sh) — Shell execution bridge.
* [`dotfiles/.config/omarchy/plugins/sanjith.antigravity/assets/antigravity.svg`](file:///home/sanjith/Projects/omarchy_changes/dotfiles/.config/omarchy/plugins/sanjith.antigravity/assets/antigravity.svg) — Dark theme SVG mark.
* [`dotfiles/.config/omarchy/plugins/sanjith.antigravity/assets/antigravity-light.svg`](file:///home/sanjith/Projects/omarchy_changes/dotfiles/.config/omarchy/plugins/sanjith.antigravity/assets/antigravity-light.svg) — Light theme SVG mark.
* [`dotfiles/.config/omarchy/shell.json`](file:///home/sanjith/Projects/omarchy_changes/dotfiles/.config/omarchy/shell.json) — Shell configuration with widget placed on the right bar.

---

## Key Features

### 1. Seamless Theme Adaptability
The panel uses Omarchy's central theme engine (`qs.Commons.Color` and `qs.Commons.Style`), pulling `Color.foreground`, `Color.background`, `Color.accent`, `Color.urgent`, and `Style.selectedFillFor`. When the user switches themes (e.g. Gruvbox, Catppuccin, Nord, Tokyo Night), the plugin adapts instantly with zero styling discrepancies.

### 2. Dual-Window Rate Limit Tracking
- Displays exact percentages for both **remaining** quota and **used** quota.
- Color-coded meters: normal fill uses `Color.accent`; falls back to warning tint under 35% and turns `Color.urgent` under 15%.
- Formatted reset countdowns showing relative duration (e.g. `4h 39m`, `1d 1h`).

### 3. Integrated Tooling & Cross-Plugin State
- Automatically updates `~/.local/state/omarchy/agents/usage/antigravity.json`, enabling Google Antigravity within the built-in `omarchy.agents` multi-agent panel as well.
- One-click actions to launch the interactive terminal CLI (`agy`) or open the Neovim sidebar.

---

## Interactions & Keybindings

| Input | Action |
| :--- | :--- |
| **Left Click** | Open / Toggle the Antigravity dashboard |
| **Right Click** | Launch `agy` terminal CLI |
| **Middle Click** | Force-refresh live quota summary |
| `r` / `R` / `Enter` | Refresh live quota while panel is focused |
| `Esc` | Close panel |
| `Tab` | Switch to neighboring bar widget |
| `omarchy-shell sanjith.antigravity toggle` | Toggle via CLI / script / keybind |
