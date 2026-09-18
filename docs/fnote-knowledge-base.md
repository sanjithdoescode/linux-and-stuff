# Instant Personal Notes & Scratchpad TUI (`fnote`)

## Purpose
An instantaneous markdown note-taking and knowledge base manager stored directly in `~/Documents/notes`. It lets you fuzzy-browse, preview with syntax highlighting, edit in Neovim, and create new notes on the fly.

## Implementation Details

### Configuration File Modified
* [~/.zshrc](file:///home/sanjith/.zshrc)

### Code Added
```zsh
# Instant Personal Notes & Scratchpad TUI
fnote() {
    local note_dir="${NOTE_DIR:-$HOME/Documents/notes}"
    mkdir -p "$note_dir"

    local output query key selected
    output=$( (cd "$note_dir" && (fd --type f --extension md . 2>/dev/null || find . -type f -name "*.md" | sed 's|^\./||')) | \
        fzf --print-query \
            --expect=ctrl-n,ctrl-y,ctrl-d \
            --header="Notes | Enter: open/create | Ctrl-N: new | Ctrl-Y: copy | Ctrl-D: delete" \
            --preview="bat --color=always -l markdown $note_dir/{} 2>/dev/null" \
            --preview-window="right:60%:wrap" \
            --query="${*:-}")

    [[ -z "$output" ]] && return

    query=$(echo "$output" | sed -n '1p')
    key=$(echo "$output" | sed -n '2p')
    selected=$(echo "$output" | sed -n '3p')

    # Create new note if Ctrl-N pressed, or if query entered without matching existing note
    if [[ "$key" == "ctrl-n" ]] || { [[ -z "$selected" ]] && [[ -n "$query" ]]; }; then
        local note_name="${query:-untitled}"
        [[ "$note_name" != *.md ]] && note_name="${note_name}.md"
        note_name=$(echo "$note_name" | tr ' ' '-')
        local note_path="$note_dir/$note_name"
        if [[ ! -f "$note_path" ]]; then
            local title
            title=$(basename "$note_name" .md | tr '-' ' ' | awk '{for(i=1;i<=NF;i++)sub(/./,toupper(substr($i,1,1)),$i)}1')
            printf "# %s\n\n*Created: %s*\n\n" "$title" "$(date +'%Y-%m-%d %H:%M')" > "$note_path"
        fi
        ${EDITOR:-nvim} "$note_path"
        return
    fi

    [[ -z "$selected" ]] && return
    local note_path="$note_dir/$selected"

    case "$key" in
        ctrl-y)
            wl-copy < "$note_path" && echo "Copied '$selected' to clipboard."
            ;;
        ctrl-d)
            read -q "REPLY?Delete note '$selected'? (y/N) "
            echo
            if [[ "$REPLY" =~ ^[Yy]$ ]]; then
                rm -f "$note_path" && echo "Deleted '$selected'."
            fi
            ;;
        *)
            ${EDITOR:-nvim} "$note_path"
            ;;
    esac
}
```

## Usage
* **Browse existing notes**:
  ```sh
  fnote
  ```
  Fuzzy-search notes with formatted markdown preview via `bat`.
* **Open in Neovim**: Press `Enter` on any note.
* **Instant Note Creation**:
  * Type a new topic name (e.g. `docker-tips`) and press `Enter` (or `Ctrl + N`).
  * `fnote` automatically creates `~/Documents/notes/docker-tips.md` pre-populated with a markdown title and timestamp header, and opens it directly in Neovim.
* **Copy note content to clipboard**: Press `Ctrl + Y`.
* **Delete note**: Press `Ctrl + D` (prompts for confirmation).
