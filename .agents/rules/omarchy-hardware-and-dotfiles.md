# Omarchy Hardware Sysfs & Dotfiles Deployment Invariants

## 1. Hardware Sysfs Writes & Resilience
When writing or editing scripts interacting with Linux virtual sysfs (`/sys/firmware/acpi/`, `/sys/class/power_supply/`, etc.):
- **Never Silently Ignore Failures**: Do not write `if [[ -w ... ]]; then echo ...; fi` without handling the `else` branch or verifying completion.
- **Multi-Tier Fallback Pattern**: Always implement self-healing fallback:
  1. Direct unprivileged write (fast path).
  2. Passwordless `sudo -n` fallback that also heals file permissions (e.g. `chmod 0664 && chgrp wheel`) so subsequent executions do not need elevation.
  3. `pkexec` fallback as the last resort for interactive environments.
- **Persistence Across Boot**: Remember that `/sys` is volatile and resets every reboot. Ensure `udev` rules (`/etc/udev/rules.d/`) trigger on `add|change` events for `platform`, `acpi`, and `power_supply` to maintain permissions when kernel modules load asynchronously.

## 2. Dotfiles Deployment Safety (`install.sh`)
When modifying `install.sh` or handling dotfile symlinks:
- **Canonical Path Comparison**: Never assume checking `[ -L "$dest" ]` is sufficient. If an ancestor directory is already symlinked to the repository, `$dest` resolves inside the repo.
- **Self-Linking Prevention**: Always compare `[ "$(readlink -f "$dest")" = "$(readlink -f "$src")" ]` before creating or updating links to prevent replacing files with broken self-referential links.

## 3. Desktop Shell Plugin Lifecycle
When plugins in `~/.config/omarchy/plugins/` or `shell.json` are modified:
- Verify that `omarchy-shell` registers the plugin using `omarchy-shell shell listPlugins`.
- Use `omarchy-shell shell reloadConfig` and `omarchy-shell shell rescanPlugins` to trigger reload without requiring a full desktop restart.
