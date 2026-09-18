# Hyprland Shortcuts: Voxtype & Screen OCR

## Purpose
Integrates hands-free speech-to-text dictation and optical character recognition (OCR) screen capture directly into global Hyprland keyboard shortcuts.

## Implementation Details

### Configuration File Modified
* [~/.config/hypr/bindings.lua](file:///home/sanjith/.config/hypr/bindings.lua)

### Code Added
```lua
-- Voice & Capture shortcuts
o.bind("SUPER + H", "Voxtype Dictation", "voxtype record toggle")
o.bind("SUPER + SHIFT + T", "OCR Screen Capture", "omarchy capture text")
```

Hyprland was reloaded using:
```sh
hyprctl reload
```

## Features & Usage

### 1. Voice-to-Text Dictation (`Super + H`)
* **Underlying Service**: `voxtype` (Whisper model daemon running under systemd user service).
* **How to Use**:
  1. Focus any text field, terminal window, or code editor.
  2. Press **`Super + H`** once to begin recording.
  3. Speak naturally.
  4. Press **`Super + H`** again to finish recording.
  5. The audio is transcribed locally by Whisper and typed directly into the active window.

### 2. Screen OCR Text Grabber (`Super + Shift + T`)
* **Underlying Utilities**: `omarchy-capture-text` (using `grim`, `slurp`, and `tesseract`).
* **How to Use**:
  1. Press **`Super + Shift + T`**.
  2. The screen dims and a crosshair appears. Click and drag a box around any text on your screen (unselectable error messages, text in images, paused video lectures, or web documents).
  3. The text is immediately extracted via OCR and copied straight to your clipboard (`wl-copy`).
  4. Press `Ctrl + V` or `Shift + Insert` anywhere to paste it.
