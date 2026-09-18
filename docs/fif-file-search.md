# Interactive In-File Search (`fif` / `rgf`)

## Purpose
Enables real-time, fuzzy searching of text inside all files in a project, complete with a syntax-highlighted preview of the matching code and line. Pressing `Enter` opens the file in Neovim directly at the matched line number.

## Implementation Details

### Configuration File Modified
* [~/.zshrc](file:///home/sanjith/.zshrc)

### Code Added
```zsh
# Interactive Ripgrep search with FZF and bat preview (Find In Files)
fif() {
    if ! command -v rg &>/dev/null || ! command -v fzf &>/dev/null; then
        echo "fif requires ripgrep and fzf" >&2
        return 1
    fi
    local query="${*:-}"
    local selected
    if [ -n "$query" ]; then
        selected=$(rg --column --line-number --no-heading --color=always --smart-case -H "$query" 2>/dev/null |
            fzf --ansi \
                --delimiter : \
                --nth 4.. \
                --preview 'bat --style=numbers --color=always --highlight-line {2} {1} 2>/dev/null' \
                --preview-window 'right:60%:+{2}-10' \
                --bind 'ctrl-/:toggle-preview' \
                --header "Results for '$query' | Enter: open | Ctrl-/: toggle preview")
    else
        local rg_cmd='rg --column --line-number --no-heading --color=always --smart-case -H {q}'
        selected=$(fzf --ansi --disabled \
            --bind "change:reload:$rg_cmd || true" \
            --delimiter : \
            --preview 'bat --style=numbers --color=always --highlight-line {2} {1} 2>/dev/null' \
            --preview-window 'right:60%:+{2}-10' \
            --bind 'ctrl-/:toggle-preview' \
            --header 'Type to search inside files | Enter: open | Ctrl-/: toggle preview')
    fi

    if [ -n "$selected" ]; then
        local file line
        file=$(echo "$selected" | cut -d: -f1 | sed 's/\x1b\[[0-9;]*m//g')
        line=$(echo "$selected" | cut -d: -f2 | sed 's/\x1b\[[0-9;]*m//g')
        ${EDITOR:-nvim} "+${line}" "$file"
    fi
}
alias rgf="fif"
```

## How to Use
* **Query search**:
  ```sh
  fif getUserProfile
  # or
  rgf getUserProfile
  ```
  Searches for `getUserProfile`, previews matches in `bat`, and lets you fuzzy-filter.
* **Interactive search**:
  ```sh
  fif
  ```
  Launches a live search where ripgrep runs dynamically as you type your query.
* **Key controls**:
  * `Enter`: Opens the selected file in Neovim (`nvim`) positioned at that exact line.
  * `Ctrl + /`: Toggles the preview window open/closed.
