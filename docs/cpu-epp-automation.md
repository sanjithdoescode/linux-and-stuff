# CPU EPP / Governor Power-Event Coupling

## Purpose
Automatically adjusts the CPU **Energy Performance Preference (EPP)** when the AC adapter is plugged in or removed, without any manual intervention. Reduces battery drain on battery power and restores responsiveness on AC.

## EPP Mapping

| Power State | EPP Value | Effect |
|---|---|---|
| AC connected | `balance_performance` | Responsive, moderate power draw |
| AC disconnected | `power` | Maximum battery life |

## Architecture

### `omarchy-set-epp` script
[`dotfiles/.local/bin/omarchy-set-epp`](../dotfiles/.local/bin/omarchy-set-epp) — sets the EPP on all CPU cores via:

```bash
omarchy-set-epp balance_performance   # on AC connect
omarchy-set-epp power                 # on AC disconnect
```

**Idempotent**: reads the current EPP value before writing — skips cores already at the target.

**Privilege escalation chain**: unprivileged write → `sudo -n` → `run0` → `pkexec` (same 4-tier pattern as `sanjith.power/set.sh`).

**Graceful fallback**: if the CPU doesn't expose EPP sysfs (e.g., AMD without `amd_pstate_epp`), the script exits cleanly with a warning rather than an error.

### Udev Rule
[`dotfiles/.config/udev/rules.d/99-cpu-epp-ac.rules`](../dotfiles/.config/udev/rules.d/99-cpu-epp-ac.rules) — triggers `omarchy-set-epp` on AC `POWER_SUPPLY_ONLINE` changes.

Installed to `/etc/udev/rules.d/` by `install.sh configure_hardware_rules()`.

### Lid-close EPP (via `hyprd`)
The `hyprd` daemon (Feature 2) also triggers EPP changes via the `switch >> on >> Lid Switch` event for when you close the lid with external monitors connected.

## Files

| File | Purpose |
|---|---|
| [`dotfiles/.local/bin/omarchy-set-epp`](../dotfiles/.local/bin/omarchy-set-epp) | EPP setter with privilege escalation |
| [`dotfiles/.config/udev/rules.d/99-cpu-epp-ac.rules`](../dotfiles/.config/udev/rules.d/99-cpu-epp-ac.rules) | AC event udev rule |

## Manual Usage

```bash
# Check current EPP on all cores
cat /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference | sort -u

# Manually set EPP
omarchy-set-epp performance
omarchy-set-epp balance_performance
omarchy-set-epp balance_power
omarchy-set-epp power

# Check available EPP values on your CPU
cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_available_preferences
```
