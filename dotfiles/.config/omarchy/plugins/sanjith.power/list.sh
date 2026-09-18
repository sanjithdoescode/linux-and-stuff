#!/bin/bash

# omarchy:summary=Returns a list of all the available power profiles on the system including cool mode.
# omarchy:args=[--active-state]

if [[ ${1:-} != "" && ${1:-} != "--active-state" ]]; then
  echo "Usage: omarchy-powerprofiles-list [--active-state]" >&2
  exit 1
fi

with_state="${1:+1}"

current_platform=""
if [[ -r /sys/firmware/acpi/platform_profile ]]; then
  current_platform=$(< /sys/firmware/acpi/platform_profile)
fi

cool_active=0
if [[ "$current_platform" == "cool" ]]; then
  cool_active=1
fi

# Print cool profile first
if [[ -n "$with_state" ]]; then
  echo -e "cool\t$cool_active"
else
  echo "cool"
fi

# Get standard profiles from powerprofilesctl
while IFS=$'\t' read -r profile active; do
  [[ -z "$profile" ]] && continue
  if (( cool_active )); then
    active=0
  fi
  if [[ -n "$with_state" ]]; then
    echo -e "$profile\t$active"
  else
    echo "$profile"
  fi
done < <(
  powerprofilesctl list 2>/dev/null |
    awk '/^\s*[* ]\s*[a-zA-Z0-9-]+:$/ {
      active = ($1 == "*") ? 1 : 0
      gsub(/^[*[:space:]]+|:$/, "")
      print $0 "\t" active
    }' |
    tac
)
