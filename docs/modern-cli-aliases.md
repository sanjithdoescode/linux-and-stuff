# Modern CLI Tool Aliases & Manpager

## Purpose
Exposes high-speed, modern Rust and Go command-line utilities already installed on your system via intuitive, short terminal commands.

## Implementation Details

### Configuration File Modified
* [~/.zshrc](file:///home/sanjith/.zshrc)

### Code Added
```zsh
# Bat (Modern syntax-highlighted cat & colored man pages)
if command -v bat &>/dev/null; then
    alias cat='bat --paging=never'
    export MANPAGER="sh -c 'col -bx | bat -l man -p'"
fi

# Modern CLI Tool Aliases
command -v lazygit &>/dev/null && alias lg="lazygit"
command -v lazydocker &>/dev/null && alias ld="lazydocker"
command -v dua &>/dev/null && alias du="dua i"
command -v rg &>/dev/null && alias rg="rg --smart-case"
```

## Aliases Summary

| Command | Underlying Tool | Function |
| :--- | :--- | :--- |
| `cat <file>` | `bat --paging=never` | Displays file contents with syntax highlighting and line numbers. |
| `man <cmd>` | `bat -l man` | Views manual pages formatted with full color and syntax highlighting. |
| `lg` | `lazygit` | Terminal UI for Git status, staging, committing, and branching. |
| `ld` | `lazydocker` | Terminal UI for managing Docker containers, images, and volumes. |
| `du` | `dua i` | Interactive, disk usage analyzer TUI for inspecting and cleaning storage. |
| `rg` | `rg --smart-case` | Ripgrep with case-insensitive search when lowercase, case-sensitive if capitalized. |
