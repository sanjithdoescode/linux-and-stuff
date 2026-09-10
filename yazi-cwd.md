# Yazi Directory Traversal on Exit (`y`)

## Purpose
By default, running `yazi` and browsing through files/directories leaves your shell in whichever directory you were in when you launched it. The `y` function wraps `yazi` so that when you quit (`q`), your shell automatically navigates (`cd`) to the directory you were currently viewing.

## Implementation Details

### Configuration Files Modified
* [~/.zshrc](file:///home/sanjith/.zshrc)
* [~/.bashrc](file:///home/sanjith/.bashrc)

### Code Added
```sh
# Yazi shell wrapper to change directory on exit
function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		builtin cd -- "$cwd"
	fi
	rm -f -- "$tmp"
}
```

## How It Works
1. Creates a temporary tracking file using `mktemp`.
2. Passes `--cwd-file="$tmp"` to Yazi, which records the active directory when you exit.
3. Reads the path using `command cat` and, if it differs from `$PWD`, switches to it using `builtin cd`.
4. Removes the temporary file.

## Usage
Simply type `y` instead of `yazi`:
```sh
y
```
Browse to any directory and press `q` to exit. Your terminal will remain at that directory.
