# Google Antigravity Usage Plugin for Omarchy

Real-time Google Antigravity quota and rate limit monitor for the Omarchy status bar.

## Overview

This plugin displays real-time quota usage and limits for Google Antigravity (`agy`), dynamically discovering whatever models you have access to:
1. **Gemini Models** (e.g. `Gemini 3.8 Flash (High)`, `Gemini 3.8 Flash (Medium)`, `Gemini 3.8 Flash (Low)`)
   - **5-Hour Session Limit**: Percentage remaining/used, progress bar, and exact reset countdown.
   - **Weekly Limit**: Percentage remaining/used, progress bar, and exact weekly reset countdown.
2. **Claude and GPT Models** (e.g. `Claude Sonnet 4.6 (Thinking)`, `Claude Opus 4.6 (Thinking)`, `GPT-OSS 120B (Medium)`)
   - **5-Hour Session Limit**: Percentage remaining/used, progress bar, and reset countdown.
   - **Weekly Limit**: Percentage remaining/used, progress bar, and reset countdown.
3. **Dynamic Model Discovery**: Automatically adapts to newly added or revamped models from the Antigravity backend without breaking. Shows model pill badges with live status, active model indicator, and total consumed token badges.
4. **Token Consumption & History**:
   - **Real-Time Burn Calculation**: Accurately tracks Input / Prompt tokens, Output tokens, Cache Read tokens, and Total tokens consumed.
   - **Per-Model Attribution**: Displays lifetime tokens consumed by each specific model (e.g. Gemini 3.8 Flash Medium).
   - **Daily Usage History Ledger**: Visual 14-day history with relative activity meters, formatted token volume, and interaction turn counts.
   - **High-Performance Incremental Cache**: Stat-based ledger (`~/.cache/omarchy/antigravity_token_ledger.json`) reads only modified transcript logs in sub-25ms.
   - **Omarchy Agent State Sync**: Automatically publishes token statistics and daily activity directly to `~/.local/state/omarchy/agents/usage/antigravity.json`.

## Features

- **Theme Native**: Integrates seamlessly with all Omarchy themes (Gruvbox, Nord, Catppuccin, etc.) via `qs.Commons.Color` and `qs.Commons.Style`.
- **Bar Widget**: Shows the official Google Antigravity vector icon alongside the lowest remaining quota percentage (e.g. `89% `).
- **Adaptive Branding Assets**:
  - `assets/Google-Antigravity-Icon-Full-Color.png`: High-resolution full-color Google Antigravity logo featured in the hero dashboard.
  - `assets/antigravity.svg`: Pure vector white SVG mark designed for dark bar themes.
  - `assets/antigravity-light.svg`: Pure vector charcoal SVG mark (`#202124`) designed for light bar themes.
  - Supports configurable `barIconStyle` (`"monochrome"` or `"color"`).
- **Dual-View Sub-Panel (Codex & Claude Code Inspired)**:
  - **Quotas & Limits View (Default)**: Focused, non-scrolling dashboard (~460px) showing 5-hour and weekly limits, active models, and quick launch card.
  - **Dedicated Token Analytics Sub-Panel**: Full-featured analytics view accessed via `[ Token Consumption ]`, featuring today's burn KPI card, prompt caching metrics, lifetime totals, per-model attribution, and a 14-day activity ledger.
- **Interactive Panel**:
  - `Left Click`: Toggle usage dashboard panel.
  - `Right Click`: Launch `agy` terminal CLI.
  - `Middle Click`: Force refresh quota and token ledger.
- **Keyboard Navigation**:
  - `t` / `T`: Toggle between Quotas and Token Consumption views.
  - `q` / `Q`: Switch to Quotas view.
  - `Left` / `Right` Arrow: Toggle between views.
  - `Esc` / `Backspace`: Return to Quotas view (or close panel if on Quotas).
  - `r` / `R` or `Enter`: Force refresh quota and token ledger.
  - `Tab`: Switch to neighboring bar panel.
- **IPC Support**: `omarchy-shell sanjith.antigravity <open|close|toggle|refresh|setView|toggleView>`.
- **Automatic Token Refresh**: Seamlessly refreshes Google OAuth tokens and stays in sync with `secret-tool` / system keyring.

## Installation & Configuration

The plugin is located at:
`~/.config/omarchy/plugins/sanjith.antigravity/`

To add it to your Omarchy bar layout, add `{"id": "sanjith.antigravity"}` to the `bar.layout.right` section in `~/.config/omarchy/shell.json`.
