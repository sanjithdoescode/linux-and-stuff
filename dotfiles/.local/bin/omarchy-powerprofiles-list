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

cool_supported=0
if [[ -r /sys/firmware/acpi/platform_profile_choices ]] && grep -qw "cool" /sys/firmware/acpi/platform_profile_choices; then
  cool_supported=1
elif [[ "$current_platform" == "cool" ]]; then
  cool_supported=1
fi

cool_active=0
if [[ "$current_platform" == "cool" ]]; then
  cool_active=1
fi

# Print cool profile first if supported
if (( cool_supported )); then
  if [[ -n "$with_state" ]]; then
    echo -e "cool\t$cool_active"
  else
    echo "cool"
  fi
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
