# Google Antigravity Usage Omarchy Plugin

## Purpose
Provides a native, theme-integrated **Omarchy bar widget and dashboard panel** for monitoring real-time **Google Antigravity (`agy`)** usage, quotas, and rolling rate limits.

The plugin dynamically discovers all available models and their live rate limit windows:
1. **Gemini Models** (`Gemini 3.8 Flash (High)`, `Gemini 3.8 Flash (Medium)`, `Gemini 3.8 Flash (Low)`)
   - **5-Hour Session Window**: Rate limit meter, remaining vs used percentage, and reset countdown.
   - **Weekly Rolling Window**: Rate limit meter, remaining vs used percentage, and reset countdown.
2. **Claude and GPT Models** (`Claude Sonnet 4.6 (Thinking)`, `Claude Opus 4.6 (Thinking)`, `GPT-OSS 120B (Medium)`)
   - **5-Hour Session Window**: Rate limit meter, remaining vs used percentage, and reset countdown.
   - **Weekly Rolling Window**: Rate limit meter, remaining vs used percentage, and reset countdown.
3. **Dynamic Model Adaptation**: Automatically adapts to model roster revamps without hardcoding or breaking into "Loading..." states.
4. **Token Consumption & History Engine**:
   - Calculates prompt / input, generated output, and cache read tokens per model and globally.
   - Provides a 14-day token burn history ledger with visual activity bars and step counts.
   - High-performance stat caching keeps execution latency under 25ms.

---

## Architecture & Implementation

### Files Created
* [`dotfiles/.config/omarchy/plugins/sanjith.antigravity/manifest.json`](file:///home/sanjith/Projects/omarchy_changes/dotfiles/.config/omarchy/plugins/sanjith.antigravity/manifest.json) — Plugin metadata, schema, and Omarchy bar-widget registration.
* [`dotfiles/.config/omarchy/plugins/sanjith.antigravity/Panel.qml`](file:///home/sanjith/Projects/omarchy_changes/dotfiles/.config/omarchy/plugins/sanjith.antigravity/Panel.qml) — Quickshell QML panel with animated meters, keyboard controls, token consumption dashboard, and 14-day history view.
* [`dotfiles/.config/omarchy/plugins/sanjith.antigravity/get_usage.py`](file:///home/sanjith/Projects/omarchy_changes/dotfiles/.config/omarchy/plugins/sanjith.antigravity/get_usage.py) — Live API scraper, OAuth token auto-refresher, local session aggregator, and incremental token usage ledger parser.
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

### 3. Dual-View Sub-Panel Architecture (Codex & Claude Code Inspired)
- **View 1: Quotas & Limits Overview (Default)**:
  - Clean, compact non-scrolling layout (~460px height).
  - Prominent 5-hour session and weekly rate limit meters with reset countdowns and warning states.
  - Active model indicator and model group pills.
  - Direct entry point teaser to token analytics: `[ Analytics → ]`.
- **View 2: Dedicated Token Consumption Sub-Panel**:
  - Full-screen analytics sub-panel with `← Back to Quotas` navigation.
  - **Today's Burn Hero KPI Card**: Large bold metric with 3-part matrix for Prompt (Input), Output (Generation), and Cache Read tokens.
  - **Lifetime Totals**: All-time tokens burned, conversations, and interaction turns.
  - **Model Attribution**: Live tokens consumed by each specific model.
  - **14-Day Visual Ledger**: Daily relative consumption bars, turn counts, and detailed prompt/output/cache breakdown.

### 4. Integrated Tooling & Cross-Plugin State
- Automatically updates `~/.local/state/omarchy/agents/usage/antigravity.json`, enabling Google Antigravity within the built-in `omarchy.agents` multi-agent panel as well.
- One-click actions to launch the interactive terminal CLI (`agy`) or open the Neovim sidebar.

---

## Interactions & Keybindings

| Input | Action |
| :--- | :--- |
| **Left Click** | Open / Toggle the Antigravity dashboard |
| **Right Click** | Launch `agy` terminal CLI |
| **Middle Click** | Force-refresh live quota summary |
| `t` / `T` | Toggle between Quotas and Token Consumption views |
| `q` / `Q` | Switch directly to Quotas view |
| `Left` / `Right` Arrow | Switch between Quotas and Token Consumption views |
| `Esc` / `Backspace` | Return from Token view to Quotas view; closes panel if on Quotas view |
| `r` / `R` / `Enter` | Refresh live quota & ledger while panel is focused |
| `Tab` | Switch to neighboring bar widget |
| `omarchy-shell sanjith.antigravity toggle` | Toggle via CLI / script / keybind |
| `omarchy-shell sanjith.antigravity toggleView` | Toggle views via IPC |
