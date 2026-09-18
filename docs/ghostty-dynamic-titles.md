# Dynamic Ghostty Tab & Window Renaming

## Purpose
Dynamically updates the terminal tab and window title using standard ANSI OSC escape sequences (`\e]0;...\a`).

* When idle at the prompt: Shows your current working directory (e.g. `~/Documents/omarchy_changes`).
* When running a command: Displays the active command followed by the directory (e.g. `nvim — ~/Documents/omarchy_changes` or `cargo — ~/Projects/api`).
* Keeps your Hyprland taskbar, window switchers, and Ghostty tabs instantly identifiable.

## Implementation Details

### Configuration File Modified
* [~/.zshrc](file:///home/sanjith/.zshrc)

### Code Added
```zsh
autoload -Uz add-zsh-hook

# Dynamically update Ghostty tab/window titles
_update_title_preexec() {
    local cmd="${1%% *}"
    print -Pn "\e]0;${cmd} — %~\a"
}

_update_title_precmd() {
    print -Pn "\e]0;%~\a"
}

add-zsh-hook preexec _update_title_preexec
add-zsh-hook precmd _update_title_precmd
```
