# Auto Desktop Notifications for Long Commands

## Purpose
Monitors long-running shell commands (such as package upgrades, builds, large git clones, or test suites) and automatically sends a native Wayland desktop notification (`notify-send`) when the task finishes.

* Alerts only trigger if the command ran for **10 seconds or longer**.
* Displays the command name, total elapsed time, and completion status:
  * ✓ Success notification if exit status is 0.
  * ✗ Error notification (with exit code) if the command failed.
* Automatically ignores interactive programs where spending time is normal (`nvim`, `man`, `tmux`, `yazi`, `fzf`, `fkill`, `lazygit`, etc.).

## Implementation Details

### Configuration File Modified
* [~/.zshrc](file:///home/sanjith/.zshrc)

### Code Added
```zsh
zmodload zsh/datetime 2>/dev/null
autoload -Uz add-zsh-hook

# Long-running command desktop notification (threshold: 10 seconds)
_notify_preexec() {
    _cmd_start_time=$EPOCHSECONDS
    _last_command="$1"
}

_notify_precmd() {
    local exit_code=$?
    if [[ -n $_cmd_start_time ]]; then
        local elapsed=$(( EPOCHSECONDS - _cmd_start_time ))
        unset _cmd_start_time

        if (( elapsed >= 10 )); then
            # Skip interactive TUIs where long time is expected
            local first_word="${${(z)_last_command}[1]}"
            case "$first_word" in
                nvim|vi|nano|man|less|more|top|htop|btop|tmux|ssh|yazi|lg|lazygit|ld|lazydocker|fzf|fif|rgf|fkill|ftldr|ta|ts|tmux-sessionizer)
                    return
                    ;;
            esac

            local icon="dialog-information"
            local status_msg="completed in ${elapsed}s"
            if (( exit_code != 0 )); then
                icon="dialog-error"
                status_msg="failed (code $exit_code) after ${elapsed}s"
            fi

            notify-send -u normal -i "$icon" "Terminal Task" "$_last_command\n$status_msg" 2>/dev/null
        fi
    fi
}

add-zsh-hook preexec _notify_preexec
add-zsh-hook precmd _notify_precmd
```

## Usage
Simply run your commands normally. If you run:
```sh
sleep 11
# or
yay -Syu
```
and switch to your browser or another window, your desktop will pop up a notification once it finishes without needing any special wrapper syntax.
