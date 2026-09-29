# Omarchy Hardware Sysfs & Dotfiles Deployment Invariants

## 1. Hardware Sysfs Writes & Resilience
When writing or editing scripts interacting with Linux virtual sysfs (`/sys/firmware/acpi/`, `/sys/class/power_supply/`, `/sys/class/firmware-attributes/`, etc.):
- **Never Silently Ignore Failures**: Do not write `if [[ -w ... ]]; then echo ...; fi` without handling the `else` branch or verifying completion.
- **Dual-Backend Hardware Support**: On vendor laptops (especially Dell), firmware updates may deprecate legacy SMBIOS tokens and remove standard battery attributes (`/sys/class/power_supply/BAT*/charge_control_*`). Always provide fallback to vendor WMI firmware attributes (`/sys/class/firmware-attributes/dell-wmi-sysman/attributes/CustomCharge*`) and persisted user state files.
- **Firmware Preconditions**: Verify and set required configuration prerequisites before modifying thresholds (e.g., ensuring `PrimaryBattChargeCfg=Custom` on Dell WMI before attempting to write `CustomChargeStart` / `CustomChargeStop`).
- **Sequence-Safe Invariants**: Enforce kernel and firmware invariants (e.g. `start <= stop`). When increasing thresholds, raise `stop` before `start`; when decreasing, lower `start` before `stop`.
- **Multi-Tier Fallback Pattern**: Always implement self-healing fallback:
  1. Direct unprivileged write (fast path).
  2. Passwordless `sudo -n` fallback.
  3. Polkit `run0` fallback (standard on modern systemd distros).
  4. `pkexec` fallback as the last resort for interactive GUI sessions.
  Upon elevation, always heal file permissions (e.g. `chmod 0664 && chgrp wheel`) so subsequent executions run unprivileged.
- **Persistence Across Boot (udev + tmpfiles.d)**: Remember that `/sys` is volatile and resets every reboot. Deploy both:
  - `udev` rules (`/etc/udev/rules.d/`) matching `add|change` on `power_supply`, `firmware-attributes`, `platform`, and `acpi`.
  - `systemd-tmpfiles` configs (`/etc/tmpfiles.d/`) to initialize permissions at early boot.

## 2. Dotfiles Deployment Safety (`install.sh`)
When modifying `install.sh` or handling dotfile symlinks:
- **Canonical Path Comparison**: Never assume checking `[ -L "$dest" ]` is sufficient. If an ancestor directory is already symlinked to the repository, `$dest` resolves inside the repo.
- **Self-Linking Prevention**: Always compare `[ "$(readlink -f "$dest")" = "$(readlink -f "$src")" ]` before creating or updating links to prevent replacing files with broken self-referential links.

## 3. Desktop Shell Plugin Lifecycle
When plugins in `~/.config/omarchy/plugins/` or `shell.json` are modified:
- Verify that `omarchy-shell` registers the plugin using `omarchy-shell shell listPlugins`.
- Use `omarchy-shell shell reloadConfig` and `omarchy-shell shell rescanPlugins` to trigger reload without requiring a full desktop restart.

## 4. Hyprland & Omarchy Lua Configuration Invariants
When modifying `dotfiles/.config/hypr/*.lua` or Omarchy desktop bindings:
- **Global Config Scope (`hl.config`)**: Never call pseudo-functions like `hl.decoration(...)`, `hl.misc(...)`, or `hl.general(...)`. All compositor settings must be applied via `hl.config({ <section> = { ... } })` (e.g., `hl.config({ decoration = { dim_special = 0.3 } })`).
- **Workspace & Window Rules**:
  - For workspace rules (such as `on_created_empty`), call `hl.workspace_rule({ workspace = "special:<name>", on_created_empty = "..." })`.
  - For window rules, call Omarchy's built-in helper `o.window(match_class, rules_table)` (which delegates to `hl.window_rule`).
- **Dispatchers**:
  - To toggle special workspaces, use `hl.dsp.workspace.toggle_special(name)` (do NOT use `hl.dsp.togglespecialworkspace`).
- **Binary Existence Checks**:
  - Never use `os.execute("command -v ...")` inside Hyprland Lua files (the compositor reaps child processes asynchronously, breaking exit code retrieval).
  - Always use Omarchy's built-in `o.cmd_present("binary_name")` helper.
- **Desktop Subsystem Ownership (Idle & Lock)**:
  - DPMS and screensaver timeouts are NOT Hyprland compositor properties. They are owned by Omarchy's `omarchy.idle` Quickshell service in `~/.config/omarchy/shell.json`.
  - Manual lock/screensaver bindings should dispatch `omarchy-screensaver` or `omarchy-system-lock`.
- **Mandatory Verification**:
  - After modifying any Hyprland Lua config, ALWAYS run `hyprctl reload && hyprctl configerrors`.
  - Assert that `hyprctl configerrors` returns completely empty before completing any Hyprland-related task.
