# Interactive FZF Previews (`fd`, `bat`, `eza`)

## Purpose
Supercharges FZF’s built-in shortcuts (`Ctrl+T` and `Alt+C`) with modern CLI utilities:
* Uses `fd` instead of `find` (respects `.gitignore`, includes hidden files, ignores `.git/`).
* Adds a side preview pane with syntax-highlighted code via `bat`.
* Adds an interactive directory tree preview via `eza`.

## Implementation Details

### Configuration File Modified
* [~/.zshrc](file:///home/sanjith/.zshrc)

### Code Added
```zsh
# FZF Integration & Interactive Previews
[ -f /usr/share/fzf/key-bindings.zsh ] && source /usr/share/fzf/key-bindings.zsh
[ -f /usr/share/fzf/completion.zsh ] && source /usr/share/fzf/completion.zsh

if command -v fzf &>/dev/null; then
    export FZF_DEFAULT_OPTS="--height 50% --layout=reverse --border --inline-info"
    if command -v fd &>/dev/null; then
        export FZF_DEFAULT_COMMAND='fd --type f --strip-cwd-prefix --hidden --follow --exclude .git'
        export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
        export FZF_ALT_C_COMMAND='fd --type d --strip-cwd-prefix --hidden --follow --exclude .git'
    fi
    if command -v bat &>/dev/null; then
        export FZF_CTRL_T_OPTS="--preview 'bat -n --color=always --line-range :300 {}' --preview-window=right:60%"
    fi
    if command -v eza &>/dev/null; then
        export FZF_ALT_C_OPTS="--preview 'eza --tree --color=always {} | head -200' --preview-window=right:60%"
    fi
fi
```

## Keybindings & Shortcuts

| Shortcut | Action | Preview Pane |
| :--- | :--- | :--- |
| **`Ctrl + T`** | Fuzzy search files in the current directory tree | Live syntax-highlighted preview of the selected file with `bat` |
| **`Alt + C`** | Fuzzy search directories and `cd` into selection | Live tree structure of directory contents with `eza` |
