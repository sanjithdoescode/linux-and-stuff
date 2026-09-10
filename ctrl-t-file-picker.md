# Interactive File Search TUI (`Ctrl + T`) & FZF Shortcuts

## Purpose
Enables full-screen or half-screen interactive fuzzy file finding right from your command prompt. Pressing `Ctrl + T` opens a live, syntax-highlighted picker powered by `fd` and `bat`.

Selecting a file (or multiple files using `Tab`) automatically injects the chosen file path(s) directly into your command line at your cursor position.

## Implementation Details

### Configuration File Modified
* [~/.zshrc](file:///home/sanjith/.zshrc)

### Code Configured
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

## How to Use `Ctrl + T`
1. **While composing any command**:
   * Type `nvim ` (or `cat `, `git add `, `rm `, `code `).
   * Press **`Ctrl + T`**.
   * An interactive fuzzy finder opens with a live `bat` preview on the right.
   * Filter for your file, press `Enter`, and the relative path is inserted directly into your prompt.
2. **Multi-Selection**:
   * Press `Tab` on multiple files to select them, then hit `Enter`. All selected paths will be inserted space-separated.
3. **Stand-Alone File Search**:
   * Press **`Ctrl + T`** on an empty prompt to search for any file, hit `Enter`, and run or inspect the inserted path.

## Companion FZF Shortcuts

| Shortcut | Description | Preview Pane |
| :--- | :--- | :--- |
| **`Ctrl + T`** | Interactive file search & buffer insertion | Line-numbered syntax highlighting via `bat` |
| **`Alt + C`** | Interactive directory jumping (`cd`) | Tree hierarchy structure via `eza` |
| **`Ctrl + R`** | Fuzzy command history search | Command preview & buffer replacement |
| **`**<Tab>`** | Fuzzy completion trigger for paths, SSH hosts, PIDs | Context-sensitive preview |
