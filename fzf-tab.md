# Interactive Tab Completion (`fzf-tab`)

## Purpose
Replaces Zsh’s default static completion menu with a floating, interactive `fzf` picker. Every tab completion (files, directories, systemd units, processes, command arguments) can now be fuzzy searched with live preview panes.

## Implementation Details

### Plugins Installed
* [~/.zsh/plugins/fzf-tab](file:///home/sanjith/.zsh/plugins/fzf-tab) (cloned from `https://github.com/Aloxaf/fzf-tab`)

### Configuration File Modified
* [~/.zshrc](file:///home/sanjith/.zshrc)

### Code Added
```zsh
# fzf-tab (Replace default completion menu with interactive fzf)
if [ -f ~/.zsh/plugins/fzf-tab/fzf-tab.plugin.zsh ]; then
    source ~/.zsh/plugins/fzf-tab/fzf-tab.plugin.zsh
    zstyle ':completion:*:git-checkout:*' sort false
    zstyle ':completion:*:descriptions' format '[%d]'
    zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza --tree --level=1 --color=always ${(Q)realpath}'
    zstyle ':fzf-tab:complete:*:*' fzf-preview 'bat -n --color=always --line-range :200 ${(Q)realpath} 2>/dev/null'
    zstyle ':completion:*:*:*:*:processes' command "ps -u $USER -o pid,user,%cpu,%mem,command -w"
    zstyle ':fzf-tab:complete:(kill|ps):argument-rest' fzf-preview '[[ $group == "[process ID]" ]] && ps --pid=$word -o cmd --no-headers -w -w'
    zstyle ':fzf-tab:complete:(kill|ps):argument-rest' fzf-flags --preview-window=down:3:wrap
    zstyle ':fzf-tab:complete:systemctl-*:*' fzf-preview 'SYSTEMD_COLORS=1 systemctl status $word'
    zstyle ':fzf-tab:*' switch-group '<' '>'
fi
```

## Completion Previews

| Command | Action on `<Tab>` |
| :--- | :--- |
| `cd <Tab>` | Interactive popup with live `eza` directory tree view. |
| Any file command (`n <Tab>`, `cat <Tab>`) | Interactive popup with syntax-highlighted preview of the target file via `bat`. |
| `kill <Tab>` / `ps <Tab>` | Shows the full process command name, PID, and CPU/Memory usage. |
| `systemctl <Tab>` | Shows real-time systemd service unit status and recent journal logs. |
| Group Switching | Press `<` and `>` to switch between completion categories (e.g. options, commands, files). |
