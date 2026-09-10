# Wayland Clipboard History Picker (`fclip` & `fpaste`)

## Purpose
Taps into Omarchy's native Wayland clipboard daemon to provide an interactive, searchable clipboard history TUI.

* **`fclip`**: Fuzzy-searches past copied text, code blocks, URLs, and multi-line snippets with live syntax preview, copying the selection back to the active clipboard (`wl-copy`).
* **`fpaste`**: Directly outputs or inserts the selected clipboard entry into your current terminal session.
* **Terminal Hotkey (`Alt + P` / `Ctrl-X Ctrl-P`)**: ZLE widget that launches the clipboard picker while you are typing a command and injects the selected text right at your cursor.

## Implementation Details

### Configuration File Modified
* [~/.zshrc](file:///home/sanjith/.zshrc)

### Code Added
```zsh
# Wayland Clipboard History Picker (Copies selection to clipboard)
fclip() {
    local hist_file="$HOME/.local/state/omarchy/clipboard-history.json"
    if [[ ! -f "$hist_file" ]] || ! command -v jq &>/dev/null || ! command -v fzf &>/dev/null; then
        echo "fclip: clipboard history not available" >&2
        return 1
    fi
    local selected
    selected=$(jq -r 'to_entries[] | select(.value.type=="text") | "\(.key)\t\(.value.text | split("\n")[0] | .[0:80])"' "$hist_file" | \
        fzf --delimiter='\t' \
            --with-nth=2 \
            --preview="jq -r --argjson idx {1} '.[$idx].text' $hist_file | bat --color=always --style=plain" \
            --preview-window="right:60%:wrap" \
            --header="Clipboard History | Enter: copy to clipboard | Ctrl-/: toggle preview" \
            --bind="ctrl-/:toggle-preview")
    [[ -z "$selected" ]] && return
    local idx
    idx=$(echo "$selected" | cut -f1)
    jq -r --argjson idx "$idx" '.[$idx].text' "$hist_file" | wl-copy
    echo "Copied selection to clipboard!"
}

# Wayland Clipboard Paste (Outputs selection directly or inserts into command line)
fpaste() {
    local hist_file="$HOME/.local/state/omarchy/clipboard-history.json"
    if [[ ! -f "$hist_file" ]] || ! command -v jq &>/dev/null || ! command -v fzf &>/dev/null; then
        echo "fpaste: clipboard history not available" >&2
        return 1
    fi
    local selected
    selected=$(jq -r 'to_entries[] | select(.value.type=="text") | "\(.key)\t\(.value.text | split("\n")[0] | .[0:80])"' "$hist_file" | \
        fzf --delimiter='\t' \
            --with-nth=2 \
            --preview="jq -r --argjson idx {1} '.[$idx].text' $hist_file | bat --color=always --style=plain" \
            --preview-window="right:60%:wrap" \
            --header="Paste from Clipboard | Enter: paste / output | Ctrl-/: toggle preview" \
            --bind="ctrl-/:toggle-preview")
    [[ -z "$selected" ]] && return
    local idx
    idx=$(echo "$selected" | cut -f1)
    jq -r --argjson idx "$idx" '.[$idx].text' "$hist_file"
}

# ZLE Widget: Press Alt-p to open clipboard picker and insert directly into current command buffer
_fpaste-widget() {
    local text
    text=$(fpaste)
    if [[ -n "$text" ]]; then
        LBUFFER+="$text"
    fi
    [[ -n "$WIDGET" ]] && zle reset-prompt
}
zle -N _fpaste-widget
bindkey '^[p' _fpaste-widget
bindkey '^X^P' _fpaste-widget
```

## Usage
1. **Interactive search to copy back to clipboard**:
   ```sh
   fclip
   ```
   Filter through previous clipboard clips with full preview. Press `Enter` to load the clip into your clipboard.

2. **Inline Terminal Paste (`Alt + P`)**:
   While typing a command (e.g. `curl -H "Authorization: Bearer `), press **`Alt + P`**. Pick the token or text from history and press `Enter`—it will be inserted right into your prompt buffer!

3. **Output in pipe or command**:
   ```sh
   echo $(fpaste)
   ```
