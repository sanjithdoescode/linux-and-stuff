# Neovim Quick Alias (`n`)

## Purpose
Provides a single-letter shortcut to launch Neovim (`nvim`), reducing keystrokes and friction for editing files.

## Implementation Details

### Configuration Files Modified
* [~/.zshrc](file:///home/sanjith/.zshrc)
* [~/.bashrc](file:///home/sanjith/.bashrc)

### Code Added
```sh
alias n="nvim"
```

## Usage
Edit any file with `n`:
```sh
n file.txt
n ~/.zshrc
```
Or simply open Neovim:
```sh
n
```
