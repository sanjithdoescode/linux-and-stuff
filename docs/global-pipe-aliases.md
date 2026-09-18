# Global Pipe Aliases (`alias -g`)

## Purpose
Leverages Zsh's `alias -g` feature, which expands shorthand tokens **anywhere** on the command line rather than only at the start. This turns verbose piping sequences into single-character keystrokes.

## Implementation Details

### Configuration File Modified
* [~/.zshrc](file:///home/sanjith/.zshrc)

### Code Added
```zsh
# Global pipe aliases (expand anywhere in command line)
alias -g C='| wl-copy'
alias -g L='| bat --paging=always'
alias -g G='| rg'
alias -g J='| jq .'
alias -g H='| head'
alias -g T='| tail'
alias -g NE='2>/dev/null'
alias -g NUL='&>/dev/null &'
```

## Quick Reference & Usage

| Shortcut | Expands To | Example Usage | What it does |
| :--- | :--- | :--- | :--- |
| **`C`** | `\| wl-copy` | `cat ~/.ssh/id_rsa.pub C` | Copies output directly to Wayland clipboard |
| **`L`** | `\| bat --paging=always` | `ps aux L` | Paginates output with syntax highlighting & line numbers |
| **`G`** | `\| rg` | `pacman -Q G zsh` | Filters command output with fast ripgrep |
| **`J`** | `\| jq .` | `curl https://api.github.com J` | Formats and colorizes JSON payloads |
| **`H`** | `\| head` | `journalctl -xe H` | Grabs top lines of output |
| **`T`** | `\| tail` | `dmesg T` | Grabs last lines of output |
| **`NE`** | `2>/dev/null` | `fd secret NE` | Silences error messages from stderr |
| **`NUL`** | `&>/dev/null &` | `mpv video.mp4 NUL` | Detaches and silences background GUI apps |
