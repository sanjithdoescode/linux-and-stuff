# Hyprland Relative Workspace Navigation & Input Customizations

## Purpose
Documents custom window management, relative workspace navigation, and touchpad behavior configured for Hyprland on Omarchy.

## Implementation Details

### Configuration Files Modified
* [~/.config/hypr/bindings.lua](file:///home/sanjith/.config/hypr/bindings.lua)
* [~/.config/hypr/input.lua](file:///home/sanjith/.config/hypr/input.lua)
* [~/.config/hypr/looknfeel.lua](file:///home/sanjith/.config/hypr/looknfeel.lua)

### 1. Relative Workspace Navigation ([bindings.lua](file:///home/sanjith/.config/hypr/bindings.lua))
Replaces absolute workspace jumping with seamless left/right relative workspace cycling:
```lua
-- Workspace navigation overrides
hl.unbind("SUPER + LEFT")
hl.unbind("SUPER + RIGHT")
o.bind("SUPER + LEFT", "Previous workspace", hl.dsp.focus({ workspace = "r-1" }))
o.bind("SUPER + RIGHT", "Next workspace", hl.dsp.focus({ workspace = "r+1" }))
```

* **`Super + Left`**: Focuses the previous relative workspace (`r-1`).
* **`Super + Right`**: Focuses the next relative workspace (`r+1`).

### 2. Natural Touchpad Scrolling ([input.lua](file:///home/sanjith/.config/hypr/input.lua))
Enables reverse/natural two-finger scrolling to match modern touchscreen and macOS touch gestures:
```lua
hl.config({
  input = {
    touchpad = {
      natural_scroll = true,
    },
  },
})
```

### 3. Window Corner Rounding ([looknfeel.lua](file:///home/sanjith/.config/hypr/looknfeel.lua))
Sets aesthetic border rounding across all tiled and floating windows:
```lua
hl.config({
  decoration = {
    rounding = 8,
  },
})
```
