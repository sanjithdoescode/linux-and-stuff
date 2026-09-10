# Wayland Clipboard Helpers (`copypath` & `copyfile`)

## Purpose
Integrates shell workflows with the Wayland system clipboard (`wl-copy`) to eliminate friction when sharing paths and file contents with editors, chats, or documentation.

* **`copypath`**: Resolves the full canonical absolute path of the current directory or any specified file/folder and puts it onto your clipboard.
* **`copyfile`**: Pipes the entire content of a file directly into your clipboard without opening an editor or terminal pager.

## Implementation Details

### Configuration File Modified
* [~/.zshrc](file:///home/sanjith/.zshrc)

### Code Added
```zsh
# Copy path of current directory or specified file/folder to Wayland clipboard
copypath() {
    local target="${1:-$PWD}"
    local abs_path
    abs_path=$(realpath "$target" 2>/dev/null) || { echo "copypath: invalid path '$target'" >&2; return 1; }
    if command -v wl-copy &>/dev/null; then
        printf "%s" "$abs_path" | wl-copy
    elif command -v xclip &>/dev/null; then
        printf "%s" "$abs_path" | xclip -selection clipboard
    fi
    echo "Copied to clipboard: $abs_path"
}

# Copy contents of a file directly to Wayland clipboard
copyfile() {
    if [ -z "$1" ]; then
        echo "Usage: copyfile <filename>" >&2
        return 1
    fi
    if [ ! -f "$1" ]; then
        echo "copyfile: file not found: '$1'" >&2
        return 1
    fi
    if command -v wl-copy &>/dev/null; then
        wl-copy < "$1"
    elif command -v xclip &>/dev/null; then
        xclip -selection clipboard < "$1"
    fi
    echo "Copied contents of '$1' to clipboard ($(wc -c < "$1" | awk '{print $1}') bytes)"
}
```

## Usage
* **Copy current directory path**:
  ```sh
  copypath
  ```
* **Copy a file or subfolder's absolute path**:
  ```sh
  copypath src/main.rs
  # Copied to clipboard: /home/sanjith/Documents/project/src/main.rs
  ```
* **Copy file contents straight to clipboard**:
  ```sh
  copyfile ~/.config/hypr/bindings.lua
  # Copied contents of '/home/sanjith/.config/hypr/bindings.lua' to clipboard (1820 bytes)
  ```
