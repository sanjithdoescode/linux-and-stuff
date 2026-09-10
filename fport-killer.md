# Interactive Port & Socket Inspector and Killer (`fport`)

## Purpose
Solves the common developer headache of port collision (`address already in use :::3000` / `8080` / `5432`). It scans all active listening sockets (TCP and UDP), parses the protocol, port number, process name, PID, and local address into a structured table, and lets you inspect or terminate processes with a single keypress.

## Implementation Details

### Configuration File Modified
* [~/.zshrc](file:///home/sanjith/.zshrc)

### Code Added
```zsh
# Interactive Port & Socket Inspector and Process Killer
fport() {
    if ! command -v fzf &>/dev/null; then
        echo "fport requires fzf" >&2
        return 1
    fi
    local raw_ports
    raw_ports=$(ss -tulpn 2>/dev/null | awk 'NR>1 {
        proto = $1
        local_addr = $5
        n = split(local_addr, parts, ":")
        port = parts[n]
        proc_info = $7
        proc_name = "-"
        pid = "-"
        if (match(proc_info, /"([^"]+)"/, m)) proc_name = m[1]
        if (match(proc_info, /pid=([0-9]+)/, m)) pid = m[1]
        printf "%-6s  %-7s  %-18s  %-8s  %s\n", proto, port, proc_name, pid, local_addr
    }' | sort -u -k2,2n)

    if [[ -z "$raw_ports" ]]; then
        echo "No listening ports found."
        return 0
    fi

    local output key selected
    output=$(echo "$raw_ports" | fzf \
        --header="Enter: copy port | Ctrl-X: kill process | Ctrl-Y: copy PID | Ctrl-/: toggle preview" \
        --header-first \
        --expect=ctrl-x,ctrl-y \
        --preview='
            pid=$(echo {} | awk "{print \$4}")
            port=$(echo {} | awk "{print \$2}")
            if [[ "$pid" != "-" && -n "$pid" ]]; then
                echo "=== Process Info (PID: $pid) ==="
                ps -fp "$pid" 2>/dev/null || echo "Process $pid not found"
                echo "\n=== Command Line ==="
                cat /proc/$pid/cmdline 2>/dev/null | tr "\0" " " || true
                echo "\n\n=== Network Sockets ==="
                ss -tulpn "sport = :$port" 2>/dev/null
            else
                echo "=== Port :$port (System / root process) ==="
                ss -tulpn "sport = :$port" 2>/dev/null
            fi
        ' \
        --preview-window="right:60%:wrap" \
        --bind="ctrl-/:toggle-preview")

    [[ -z "$output" ]] && return

    key=$(echo "$output" | sed -n '1p')
    selected=$(echo "$output" | sed -n '2p')
    [[ -z "$selected" ]] && return

    local port pid proc_name
    port=$(echo "$selected" | awk '{print $2}')
    proc_name=$(echo "$selected" | awk '{print $3}')
    pid=$(echo "$selected" | awk '{print $4}')

    case "$key" in
        ctrl-x)
            if [[ "$pid" == "-" || -z "$pid" ]]; then
                echo "Cannot kill: PID not visible without root privileges (try: sudo ss -tulpn)." >&2
                return 1
            fi
            if kill -9 "$pid" 2>/dev/null; then
                echo "Killed process '$proc_name' (PID $pid) on port :$port."
            else
                echo "Failed to kill PID $pid (try: sudo kill -9 $pid)." >&2
            fi
            ;;
        ctrl-y)
            if [[ "$pid" != "-" && -n "$pid" ]]; then
                printf "%s" "$pid" | wl-copy
                echo "Copied PID $pid to clipboard."
            fi
            ;;
        *)
            printf "%s" "$port" | wl-copy
            echo "Copied port :$port to clipboard."
            ;;
    esac
}
```

## Usage
1. Run `fport`:
   ```sh
   fport
   ```
2. Controls:
   * `Enter`: Copies the selected port number (e.g. `3000`) straight to clipboard.
   * `Ctrl + X`: Immediately sends `SIGKILL` (`kill -9`) to the process holding that port, freeing it for your development server.
   * `Ctrl + Y`: Copies the PID of the process to your clipboard.
   * `Ctrl + /`: Toggles the preview pane.
