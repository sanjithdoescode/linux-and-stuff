#!/bin/bash

# omarchy:summary=Set battery charge start and stop thresholds
# omarchy:args=[get|set <start> <stop>|apply]

set -euo pipefail

power_supply_path="${OMARCHY_POWER_SUPPLY_PATH:-/sys/class/power_supply}"
sysman_path="${OMARCHY_SYSMAN_PATH:-/sys/class/firmware-attributes/dell-wmi-sysman/attributes}"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/power"
state_file="$state_dir/thresholds"

find_battery() {
  for b in "$power_supply_path"/BAT*; do
    if [[ -d "$b" ]]; then
      echo "$b"
      return 0
    fi
  done
  return 1
}

BATTERY_PATH=$(find_battery || true)
if [[ -z "$BATTERY_PATH" ]]; then
  echo "No battery found" >&2
  exit 1
fi

elevate_cmd() {
  local cmd="$1"
  if sudo -n true 2>/dev/null; then
    sudo -n bash -c "$cmd" && return 0
  fi
  if command -v run0 >/dev/null 2>&1; then
    run0 bash -c "$cmd" && return 0
  fi
  if command -v pkexec >/dev/null 2>&1; then
    pkexec bash -c "$cmd" && return 0
  fi
  return 1
}

get_thresholds() {
  local start=""
  local stop=""

  # 1. Try standard sysfs battery attributes
  if [[ -n "$BATTERY_PATH" ]]; then
    if [[ -r "$BATTERY_PATH/charge_control_start_threshold" ]]; then
      start=$(<"$BATTERY_PATH/charge_control_start_threshold")
    fi
    if [[ -r "$BATTERY_PATH/charge_control_end_threshold" ]]; then
      stop=$(<"$BATTERY_PATH/charge_control_end_threshold")
    fi
  fi

  # 2. Try Dell WMI sysman attributes (Inspiron/Latitude/XPS firmware)
  if [[ -z "$stop" && -d "$sysman_path/CustomChargeStop" ]]; then
    if [[ -r "$sysman_path/CustomChargeStart/current_value" ]]; then
      start=$(<"$sysman_path/CustomChargeStart/current_value")
    fi
    if [[ -r "$sysman_path/CustomChargeStop/current_value" ]]; then
      stop=$(<"$sysman_path/CustomChargeStop/current_value")
    fi
  fi

  # 3. Fallback to persisted state file if readable
  if [[ -z "$stop" && -r "$state_file" ]]; then
    # shellcheck source=/dev/null
    source "$state_file" 2>/dev/null || true
    start="${START:-}"
    stop="${STOP:-}"
  fi

  echo "start=${start:-50} stop=${stop:-55}"
}

set_thresholds() {
  local start="${1:-}"
  local stop="${2:-}"

  if [[ -z "$start" || -z "$stop" ]]; then
    echo "Usage: threshold.sh set <start_percent> <stop_percent>" >&2
    exit 2
  fi

  if ! [[ "$start" =~ ^[0-9]+$ && "$stop" =~ ^[0-9]+$ ]]; then
    echo "Thresholds must be integers" >&2
    exit 2
  fi

  # Hardware boundary clamps (Dell & standard sysfs)
  (( start < 50 )) && start=50
  (( start > 95 )) && start=95
  (( stop < 55 )) && stop=55
  (( stop > 100 )) && stop=100

  if (( start > stop - 5 )); then
    start=$(( stop - 5 ))
    (( start < 50 )) && start=50
  fi

  local has_sysfs=false
  local has_sysman=false

  if [[ -n "$BATTERY_PATH" && -f "$BATTERY_PATH/charge_control_end_threshold" ]]; then
    has_sysfs=true
  fi

  if [[ -d "$sysman_path/CustomChargeStop" ]]; then
    has_sysman=true
  fi

  if [[ "$has_sysfs" == false && "$has_sysman" == false ]]; then
    echo "Hardware charge threshold control is not supported on this device" >&2
    exit 1
  fi

  # 1. Update standard sysfs power_supply if supported
  if [[ "$has_sysfs" == true ]]; then
    # Ensure charge_types is Custom if present
    if [[ -w "$BATTERY_PATH/charge_types" ]]; then
      echo "Custom" > "$BATTERY_PATH/charge_types" 2>/dev/null || true
    fi

    local current_start=50
    local current_stop=55
    if [[ -r "$BATTERY_PATH/charge_control_start_threshold" ]]; then
      current_start=$(<"$BATTERY_PATH/charge_control_start_threshold")
    fi
    if [[ -r "$BATTERY_PATH/charge_control_end_threshold" ]]; then
      current_stop=$(<"$BATTERY_PATH/charge_control_end_threshold")
    fi

    local write_ok=true
    if (( stop > current_stop )); then
      echo "$stop" > "$BATTERY_PATH/charge_control_end_threshold" 2>/dev/null || write_ok=false
      echo "$start" > "$BATTERY_PATH/charge_control_start_threshold" 2>/dev/null || write_ok=false
    else
      echo "$start" > "$BATTERY_PATH/charge_control_start_threshold" 2>/dev/null || write_ok=false
      echo "$stop" > "$BATTERY_PATH/charge_control_end_threshold" 2>/dev/null || write_ok=false
    fi

    if [[ "$write_ok" == false ]]; then
      local cmd=""
      if (( stop > current_stop )); then
        cmd="[[ -f '$BATTERY_PATH/charge_types' ]] && echo 'Custom' > '$BATTERY_PATH/charge_types' 2>/dev/null || true; echo '$stop' > '$BATTERY_PATH/charge_control_end_threshold' && echo '$start' > '$BATTERY_PATH/charge_control_start_threshold'"
      else
        cmd="[[ -f '$BATTERY_PATH/charge_types' ]] && echo 'Custom' > '$BATTERY_PATH/charge_types' 2>/dev/null || true; echo '$start' > '$BATTERY_PATH/charge_control_start_threshold' && echo '$stop' > '$BATTERY_PATH/charge_control_end_threshold'"
      fi
      cmd="$cmd; chmod 0664 '$BATTERY_PATH'/charge_control_* '$BATTERY_PATH'/charge_types 2>/dev/null && chgrp wheel '$BATTERY_PATH'/charge_control_* '$BATTERY_PATH'/charge_types 2>/dev/null || true"
      elevate_cmd "$cmd" || {
        echo "Failed to write charge thresholds to sysfs" >&2
        exit 1
      }
    fi
  fi

  # 2. Update Dell WMI sysman attributes if supported (BIOS 1.43+)
  if [[ "$has_sysman" == true ]]; then
    if [[ -w "$sysman_path/PrimaryBattChargeCfg/current_value" ]]; then
      echo "Custom" > "$sysman_path/PrimaryBattChargeCfg/current_value" 2>/dev/null || true
    fi

    local current_start=50
    local current_stop=55
    if [[ -r "$sysman_path/CustomChargeStart/current_value" ]]; then
      current_start=$(<"$sysman_path/CustomChargeStart/current_value")
    fi
    if [[ -r "$sysman_path/CustomChargeStop/current_value" ]]; then
      current_stop=$(<"$sysman_path/CustomChargeStop/current_value")
    fi

    local write_ok=true
    if (( stop > current_stop )); then
      echo "$stop" > "$sysman_path/CustomChargeStop/current_value" 2>/dev/null || write_ok=false
      echo "$start" > "$sysman_path/CustomChargeStart/current_value" 2>/dev/null || write_ok=false
    else
      echo "$start" > "$sysman_path/CustomChargeStart/current_value" 2>/dev/null || write_ok=false
      echo "$stop" > "$sysman_path/CustomChargeStop/current_value" 2>/dev/null || write_ok=false
    fi

    if [[ "$write_ok" == false ]]; then
      local cmd=""
      if (( stop > current_stop )); then
        cmd="echo 'Custom' > '$sysman_path/PrimaryBattChargeCfg/current_value' 2>/dev/null || true; echo '$stop' > '$sysman_path/CustomChargeStop/current_value' && echo '$start' > '$sysman_path/CustomChargeStart/current_value'"
      else
        cmd="echo 'Custom' > '$sysman_path/PrimaryBattChargeCfg/current_value' 2>/dev/null || true; echo '$start' > '$sysman_path/CustomChargeStart/current_value' && echo '$stop' > '$sysman_path/CustomChargeStop/current_value'"
      fi
      cmd="$cmd; chmod 0664 '$sysman_path'/CustomCharge{Start,Stop}/current_value '$sysman_path'/PrimaryBattChargeCfg/current_value 2>/dev/null && chgrp wheel '$sysman_path'/CustomCharge{Start,Stop}/current_value '$sysman_path'/PrimaryBattChargeCfg/current_value 2>/dev/null || true"
      elevate_cmd "$cmd" || {
        echo "Failed to write charge thresholds to Dell sysman" >&2
        exit 1
      }
    fi
  fi

  # Persist chosen thresholds
  mkdir -p "$state_dir"
  printf 'START=%s\nSTOP=%s\n' "$start" "$stop" > "$state_file"

  echo "Thresholds set: start=${start}% stop=${stop}%"
}

action="${1:-get}"
case "$action" in
  get)
    get_thresholds
    ;;
  set)
    shift
    set_thresholds "$@"
    ;;
  apply)
    if [[ -r "$state_file" ]]; then
      source "$state_file"
      set_thresholds "${START:-50}" "${STOP:-55}"
    fi
    ;;
  *)
    echo "Unknown action: $action" >&2
    exit 1
    ;;
esac
