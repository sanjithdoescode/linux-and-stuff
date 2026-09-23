# Battery Charge Thresholds & Power Management Omarchy Plugin

## Purpose
Provides an advanced, native **Omarchy bar widget and interactive power panel** for real-time battery telemetry, ACPI power profile management, and hardware battery charge threshold control.

The plugin introduces fine-grained charge limit control directly into the Omarchy Hyprland desktop, allowing users to configure both the **charging start threshold** and **stop threshold** to preserve battery health during extended AC/docked use.

---

## Architecture & Implementation

### Files Created & Modified
* [`dotfiles/.config/omarchy/plugins/sanjith.power/manifest.json`](file:///home/sanjith/Projects/omarchy_changes/dotfiles/.config/omarchy/plugins/sanjith.power/manifest.json) — Plugin metadata, category (`System`), kinds (`bar-widget`), and entry point registration.
* [`dotfiles/.config/omarchy/plugins/sanjith.power/Panel.qml`](file:///home/sanjith/Projects/omarchy_changes/dotfiles/.config/omarchy/plugins/sanjith.power/Panel.qml) — Quickshell QML panel with animated battery progress bar, dual threshold sliders, quick presets, keyboard navigation, and theme integration.
* [`dotfiles/.config/omarchy/plugins/sanjith.power/threshold.sh`](file:///home/sanjith/Projects/omarchy_changes/dotfiles/.config/omarchy/plugins/sanjith.power/threshold.sh) — Kernel sysfs threshold setter with sequence-safe order handling, boundary clamping, and state persistence.
* [`dotfiles/.config/omarchy/plugins/sanjith.power/status.sh`](file:///home/sanjith/Projects/omarchy_changes/dotfiles/.config/omarchy/plugins/sanjith.power/status.sh) — Instantaneous battery state and threshold telemetry collector.
* [`dotfiles/.config/omarchy/plugins/sanjith.power/Model.js`](file:///home/sanjith/Projects/omarchy_changes/dotfiles/.config/omarchy/plugins/sanjith.power/Model.js) — Pure JS business logic for threshold normalization (`normalizeThresholds`), icons, and battery health calculation.
* [`dotfiles/.config/omarchy/plugins/sanjith.power/set.sh`](file:///home/sanjith/Projects/omarchy_changes/dotfiles/.config/omarchy/plugins/sanjith.power/set.sh) — Power profile dispatcher remembering separate profiles for AC vs Battery modes.
* [`dotfiles/.config/omarchy/plugins/sanjith.power/list.sh`](file:///home/sanjith/Projects/omarchy_changes/dotfiles/.config/omarchy/plugins/sanjith.power/list.sh) — Enumerates supported ACPI power profiles.
* [`dotfiles/.config/omarchy/plugins/sanjith.power/README.md`](file:///home/sanjith/Projects/omarchy_changes/dotfiles/.config/omarchy/plugins/sanjith.power/README.md) — Plugin documentation and installation overview.

---

## Key Features

### 1. Dual Hardware Charge Threshold Sliders
* **Start Charging Slider (50% – 95%)**: Sets the battery level at which charging begins when connected to AC power.
* **Stop Charging Slider (55% – 100%)**: Sets the battery level at which charging stops, switching the laptop to direct AC power passthrough.
* **Dynamic Bound Enforcement**: Enforces the hardware constraint `start <= stop - 5`:
  * Dragging Stop below `Start + 5%` pulls Start down automatically.
  * Dragging Start above `Stop - 5%` pushes Stop up automatically.
* **One-Click Presets**:
  * **Desk 55%** (`50% – 55%`): Battery longevity for plugged-in/docked desk work.
  * **Balance 80%** (`75% – 80%`): Optimal daily balance between mobility and battery longevity.
  * **Full 100%** (`95% – 100%`): Full capacity for travel.

### 2. Sequence-Safe Kernel Sysfs Writes
The Linux battery charging subsystem strictly enforces that `start_threshold <= end_threshold` at every instant. Writing thresholds in the wrong order causes the kernel to reject the update.
[`threshold.sh`](file:///home/sanjith/Projects/omarchy_changes/dotfiles/.config/omarchy/plugins/sanjith.power/threshold.sh) dynamically evaluates whether thresholds are increasing or decreasing:
* **Increasing**: Raises the stop threshold first, then raises the start threshold.
* **Decreasing**: Lowers the start threshold first, then lowers the stop threshold.
* Automatically writes `"Custom"` to `/sys/class/power_supply/BAT*/charge_types` when supported (required by Dell smbios/WMI drivers).

### 3. Passwordless Unprivileged Execution
To prevent intrusive password prompts while adjusting sliders in the UI:
* `/etc/tmpfiles.d/battery-charge-thresholds.conf` ensures `0664 root:wheel` permissions on boot.
* `/etc/udev/rules.d/99-battery-charge-thresholds.rules` applies `0664 root:wheel` on hotplug and battery uevents.
* [`threshold.sh`](file:///home/sanjith/Projects/omarchy_changes/dotfiles/.config/omarchy/plugins/sanjith.power/threshold.sh) executes unprivileged writes directly, falling back to `pkexec` if sysfs permissions are ever reset.

### 4. ACPI Power Profile Switching
* Native integration with `power-profiles-daemon` and `/sys/firmware/acpi/platform_profile`.
* Supports `cool`, `power-saver` (Eco), `balanced`, and `performance` modes.
* Stores and restores profile selections independently for AC and battery states.

---

## Interactions & Keybindings

| Input | Action |
| :--- | :--- |
| **Left Click** | Open / Toggle the Power panel |
| **Right Click** | Toggle percentage display in top bar button |
| `Left` / `Right` / `Up` / `Down` | Navigate power profiles via keyboard cursor |
| `Enter` / `Space` | Activate focused power profile |
| `Esc` | Close panel |
| `Tab` | Switch to neighboring bar panel |

---

## CLI & Script Usage

```bash
# Summon or toggle the panel via Omarchy Shell IPC
omarchy-shell omarchy.power toggle

# Query current battery charge thresholds
~/.config/omarchy/plugins/sanjith.power/threshold.sh get

# Set charge thresholds manually (Start: 50%, Stop: 80%)
~/.config/omarchy/plugins/sanjith.power/threshold.sh set 50 80

# Re-apply saved thresholds after reboot or wake
~/.config/omarchy/plugins/sanjith.power/threshold.sh apply

# Check raw battery status in shell format
~/.config/omarchy/plugins/sanjith.power/status.sh --shell
```
