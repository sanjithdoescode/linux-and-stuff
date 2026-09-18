# Magic Sudo Toggle (`Esc Esc` / `Alt-s`)

## Purpose
Eliminates the friction of running commands that require root privileges. Double-tapping `Esc` or pressing `Alt-s` toggles `sudo ` at the beginning of your current command line buffer without clearing your input or moving your cursor away.

If your current command line is empty, it automatically pulls your last executed command from history and prepends `sudo `, allowing you to instantly re-run a failed command with root permissions.

## Implementation Details

### Configuration File Modified
* [~/.zshrc](file:///home/sanjith/.zshrc)

### Code Added
```zsh
# Magic Sudo toggle (Double-tap Esc or Alt-s)
_toggle-sudo-widget() {
    if [[ -z $BUFFER ]]; then
        BUFFER="$(fc -ln -1 2>/dev/null | sed 's/^[[:space:]]*//')"
    fi
    if [[ $BUFFER == sudo\ * ]]; then
        BUFFER="${BUFFER#sudo }"
        (( CURSOR >= 5 )) && (( CURSOR -= 5 ))
    else
        BUFFER="sudo $BUFFER"
        (( CURSOR += 5 ))
    fi
    [[ -n "$WIDGET" ]] && zle end-of-line
}
zle -N _toggle-sudo-widget
bindkey '\e\e' _toggle-sudo-widget
bindkey '^[s' _toggle-sudo-widget
bindkey '\es' _toggle-sudo-widget
```

## Usage
1. **While typing a command**:
   ```sh
   pacman -S neovim
   ```
   Press `Esc Esc` or `Alt + s`:
   ```sh
   sudo pacman -S neovim
   ```
   Press it again to remove `sudo`.

2. **After a permission denied error**:
   If a command just failed with `Permission denied`, hit `Esc Esc` or `Alt + s` on the empty prompt to recall it with `sudo ` prepended, then press `Enter`.
