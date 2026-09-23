# My Power (`sanjith.power`) Plugin for Omarchy

Advanced battery health monitor, power profile controller, and hardware charge threshold manager for the Omarchy desktop shell bar.

---

## ⚡ Overview

`sanjith.power` is a customized Omarchy bar widget and interactive dropdown panel cloned and enhanced from `omarchy.power`. It provides comprehensive battery telemetry, dynamic power profile switching, and fine-grained hardware charge threshold sliders directly from the Omarchy status bar.

---

## ✨ Features

### 1. Battery Telemetry & Live Power Flow
* **Real-time Wattage & Battery Life**: Reads instantaneous sysfs kernel power telemetry (`power_now` or `current_now * voltage_now`) for sub-second live updates.
* **Animated Charge Fill**: Progress bar with pulse animations while energy is actively flowing.
* **Hero Status Phrases**: Alternating live status messages reflecting power intake and consumption.
* **Battery Stats**:
  * Remaining capacity vs designed capacity (`Wh`)
  * Full charge cycle count
  * Real-time charge rate / discharge draw (`W`)
  * Time to full / time remaining
  * Current threshold status and hold state

### 2. Dual Battery Charge Threshold Sliders
Enables hardware charge threshold limiting to extend laptop battery longevity, ideal for laptops docked or plugged in for long periods.
* **Start Charging Slider (50% – 95%)**: Controls the lower threshold where charging resumes.
* **Stop Charging Slider (55% – 100%)**: Controls the upper threshold where charging halts and switches to AC passthrough.
* **Interactive Dynamic Coupling**: Automatically enforces hardware safety constraints (`start <= stop - 5`):
  * Dragging Stop below `Start + 5%` automatically pulls Start down.
  * Dragging Start above `Stop - 5%` automatically pushes Stop up.
* **One-Click Presets**:
  * **Desk 55%** (`50% – 55%`): Maximizes battery lifespan when predominantly on AC power.
  * **Balance 80%** (`75% – 80%`): Recommended daily balance between mobility and battery longevity.
  * **Full 100%** (`95% – 100%`): Maximum runtime for travel and remote work.

### 3. ACPI Power Profile Switching
* Quick-switch between system power profiles:
  * **Cool**: Eco CPU scaling + enhanced cooling curves for thermal management.
  * **Eco (`power-saver`)**: Maximum energy efficiency and battery conservation.
  * **Balanced**: Standard performance for daily tasks.
  * **Performance**: Maximum CPU clocks and responsiveness.
* Automatically remembers separate power profile preferences for AC mains vs battery operation.

### 4. Zero-Friction Permissions & Persistence
* Built with non-blocking unprivileged access:
  * [`/etc/udev/rules.d/99-battery-charge-thresholds.rules`](file:///etc/udev/rules.d/99-battery-charge-thresholds.rules) and [`/etc/tmpfiles.d/battery-charge-thresholds.conf`](file:///etc/tmpfiles.d/battery-charge-thresholds.conf) configure `0664 root:wheel` access on battery sysfs attributes.
  * Sliders and presets adjust thresholds instantly without password prompts.
  * Automatically sets `charge_types` to `Custom` on Dell and compatible hardware.
  * Threshold states are persisted to `~/.local/state/omarchy/power/thresholds`.

---

## 📂 File Structure

| File | Purpose |
| :--- | :--- |
| [`manifest.json`](manifest.json) | Plugin metadata, kinds (`bar-widget`), and entry point declaration |
| [`Panel.qml`](Panel.qml) | Quickshell QML panel with animated progress bar, sliders, presets, and power profiles |
| [`Model.js`](Model.js) | Data parsing, threshold clamping (`normalizeThresholds`), icons, and battery calculation |
| [`status.sh`](status.sh) | Battery state collector emitting key-value pairs for QML consumption (`--shell`) |
| [`threshold.sh`](threshold.sh) | Safe sysfs threshold writer, state persister, and bound validator |
| [`set.sh`](set.sh) | Power profile applicator for AC and battery states |
| [`list.sh`](list.sh) | Lists available hardware power profiles and active state |

---

## 🎮 Interactions & Shortcuts

| Input | Action |
| :--- | :--- |
| **Left Click** (Bar button) | Open / Toggle the Power panel |
| **Right Click** (Bar button) | Toggle percentage display in the top bar |
| `Left` / `Right` / `Up` / `Down` | Navigate power profiles via keyboard cursor |
| `Enter` / `Space` | Apply selected power profile |
| `Esc` | Close panel |
| `Tab` | Switch to neighboring bar panel |

---

## 💻 CLI & IPC Control

Control the power plugin programmatically via [`omarchy-shell`](file:///usr/share/omarchy/bin/omarchy-shell) or standalone scripts:

```bash
# Toggle the power panel
omarchy-shell omarchy.power toggle

# Toggle percentage on top bar
omarchy-shell omarchy.power togglePercentage

# Query current battery charge thresholds
~/.config/omarchy/plugins/sanjith.power/threshold.sh get

# Set charge thresholds (Start: 75%, Stop: 80%)
~/.config/omarchy/plugins/sanjith.power/threshold.sh set 75 80

# Re-apply persisted thresholds
~/.config/omarchy/plugins/sanjith.power/threshold.sh apply

# Set power profile for current power state
~/.config/omarchy/plugins/sanjith.power/set.sh autodetect balanced
```

---

## ⚙️ Configuration

To place the widget in your bar, verify `shell.json` has `sanjith.power` registered:

```json
{
  "bar": {
    "layout": {
      "right": [
        { "id": "sanjith.power" }
      ]
    }
  }
}
```
