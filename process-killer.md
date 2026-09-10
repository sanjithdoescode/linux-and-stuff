# Interactive Process Killer (`fkill`)

## Purpose
An interactive, fuzzy process terminator powered by `fzf` and `ps`. Provides a live process list showing PID, User, CPU%, Mem%, state, runtime, and the full command path.

* Supports multi-selection with `Tab`.
* Pressing `Enter` terminates processes gracefully using `SIGTERM` (15).
* Pressing `Ctrl + X` sends an immediate force-kill signal using `SIGKILL` (9).

## Implementation Details

### Configuration File Modified
* [~/.zshrc](file:///home/sanjith/.zshrc)

### Code Added
```zsh
# Interactive Process Killer (FZF + ps)
fkill() {
    if ! command -v fzf &>/dev/null; then
        echo "fkill requires fzf" >&2
        return 1
    fi
    local pid_output key pids
    pid_output=$(ps -u "$USER" -o pid,user,%cpu,%mem,stat,time,command | sed 1d | fzf --multi \
        --header="Enter: kill (SIGTERM) | Ctrl-X: force-kill (SIGKILL) | Tab: multi-select" \
        --preview="echo {}" \
        --preview-window="down:3:wrap" \
        --expect=ctrl-x)
    [ -z "$pid_output" ] && return

    key=$(echo "$pid_output" | head -n1)
    pids=$(echo "$pid_output" | tail -n +2 | awk '{print $1}')

    if [ -n "$pids" ]; then
        if [ "$key" = "ctrl-x" ]; then
            echo "$pids" | xargs -r kill -9 2>/dev/null && echo "Force-killed PID(s): $(echo $pids | tr '\n' ' ')"
        else
            echo "$pids" | xargs -r kill -15 2>/dev/null && echo "Terminated PID(s): $(echo $pids | tr '\n' ' ')"
        fi
    fi
}
```

## Usage
1. Launch the interactive process finder:
   ```sh
   fkill
   ```
2. Type any process name, PID, or command argument (e.g. `node`, `firefox`, `python`, `discord`).
3. Controls:
   * `Tab`: Mark/unmark multiple processes for termination.
   * `Enter`: Terminate marked process(es) safely via `SIGTERM`.
   * `Ctrl + X`: Force terminate unresponsive process(es) via `SIGKILL`.
   * `Esc` or `Ctrl + C`: Exit without killing any process.
