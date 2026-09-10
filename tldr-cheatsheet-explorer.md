# Interactive Cheatsheet Explorer (`ftldr`)

## Purpose
Provides an interactive fuzzy finder for over 7,400 community-driven command cheatsheets (`tldr`). Instead of memorizing obscure flags or scrolling long man pages, `ftldr` gives you live syntax-highlighted examples rendered via `bat`.

## Implementation Details

### Configuration File Modified
* [~/.zshrc](file:///home/sanjith/.zshrc)

### Code Added
```zsh
# Interactive TLDR cheatsheet explorer
ftldr() {
    if ! command -v tldr &>/dev/null || ! command -v fzf &>/dev/null; then
        echo "ftldr requires tldr and fzf" >&2
        return 1
    fi
    local cmd
    cmd=$(tldr -l 2>/dev/null | fzf \
        --preview='tldr -m {} 2>/dev/null | bat -l markdown --color=always -p 2>/dev/null' \
        --preview-window='right:65%:wrap' \
        --header='Search TLDR cheatsheets | Enter: open page | Ctrl-/: toggle preview' \
        --bind='ctrl-/:toggle-preview' \
        --query="${*:-}")
    if [ -n "$cmd" ]; then
        tldr -m "$cmd" | bat -l markdown -p
    fi
}
```

## Usage
* **Interactive fuzzy browse**:
  ```sh
  ftldr
  ```
  Type any command (e.g. `tar`, `rsync`, `sed`, `ffmpeg`, `docker`, `git`) to view live cheatsheet examples in the right pane.
* **Direct query pre-fill**:
  ```sh
  ftldr pacman
  ```
* **Controls**:
  * `Enter`: Opens the cheatsheet directly in your terminal formatted via `bat`.
  * `Ctrl + /`: Toggles the preview window open or closed.
