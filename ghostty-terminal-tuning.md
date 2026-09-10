# Ghostty Performance Tuning & Custom Keybindings

## Purpose
Documents performance optimizations, terminal split controls, and keyboard protocol features customized in Ghostty.

## Implementation Details

### Configuration File Modified
* [~/.config/ghostty/config](file:///home/sanjith/.config/ghostty/config)

### Configurations Added & Tuned

```ini
# Shell executable
command = /usr/bin/zsh

# Fix general slowness and input latency on Hyprland
async-backend = epoll

# Mouse scroll sensitivity
mouse-scroll-multiplier = 0.95

# Extended CSI-u keyboard protocol encoding (enables Shift+Enter differentiation in Neovim/TUIs)
keybind = shift+enter=csi:13;2u
keybind = alt+shift+enter=csi:13;4u

# Clipboard operations
keybind = shift+insert=paste_from_clipboard
keybind = control+insert=copy_to_clipboard

# Split pane resizing in 100px increments
keybind = super+control+shift+alt+arrow_down=resize_split:down,100
keybind = super+control+shift+alt+arrow_up=resize_split:up,100
keybind = super+control+shift+alt+arrow_left=resize_split:left,100
keybind = super+control+shift+alt+arrow_right=resize_split:right,100
```

## Key Benefits
* **`async-backend = epoll`**: Addresses a known Wayland/Hyprland rendering bottleneck, reducing input latency and frame drops.
* **`command = /usr/bin/zsh`**: Guarantees all new terminal windows, quick terminal dropdowns, and splits spawn in Zsh regardless of environment defaults.
* **CSI-u Key Encoding**: Allows advanced Neovim plugins to map `<S-CR>` and `<M-S-CR>` distinctly from plain `Enter`.
* **Split Resizing**: Lets you fine-tune split pane widths and heights using `Super + Ctrl + Shift + Alt + Arrow Keys`.
