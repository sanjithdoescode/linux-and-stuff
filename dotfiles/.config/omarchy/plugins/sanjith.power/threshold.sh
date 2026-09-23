#!/bin/bash

# omarchy:summary=Set battery charge start and stop thresholds
# omarchy:args=[get|set <start> <stop>|apply]

set -euo pipefail

power_supply_path="${OMARCHY_POWER_SUPPLY_PATH:-/sys/class/power_supply}"
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

get_thresholds() {
  local start=""
  local stop=""
  if [[ -r "$BATTERY_PATH/charge_control_start_threshold" ]]; then
    start=$(<"$BATTERY_PATH/charge_control_start_threshold")
  fi
  if [[ -r "$BATTERY_PATH/charge_control_end_threshold" ]]; then
    stop=$(<"$BATTERY_PATH/charge_control_end_threshold")
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

  # Write in correct sequence to satisfy kernel invariant (start <= stop)
  local write_ok=true
  if (( stop > current_stop )); then
    # Moving up: raise stop threshold first, then raise start threshold
    echo "$stop" > "$BATTERY_PATH/charge_control_end_threshold" 2>/dev/null || write_ok=false
    echo "$start" > "$BATTERY_PATH/charge_control_start_threshold" 2>/dev/null || write_ok=false
  else
    # Moving down: lower start threshold first, then lower stop threshold
    echo "$start" > "$BATTERY_PATH/charge_control_start_threshold" 2>/dev/null || write_ok=false
    echo "$stop" > "$BATTERY_PATH/charge_control_end_threshold" 2>/dev/null || write_ok=false
  fi

  # Fallback to pkexec if direct write wasn't permitted
  if [[ "$write_ok" == false ]]; then
    pkexec bash -c "
      [[ -f '$BATTERY_PATH/charge_types' ]] && echo 'Custom' > '$BATTERY_PATH/charge_types' 2>/dev/null || true
      if (( $stop > $current_stop )); then
        echo '$stop' > '$BATTERY_PATH/charge_control_end_threshold'
        echo '$start' > '$BATTERY_PATH/charge_control_start_threshold'
      else
        echo '$start' > '$BATTERY_PATH/charge_control_start_threshold'
        echo '$stop' > '$BATTERY_PATH/charge_control_end_threshold'
      fi
    " || {
      echo "Failed to write charge thresholds to sysfs" >&2
      exit 1
    }
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
