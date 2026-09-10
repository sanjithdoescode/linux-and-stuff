# Prefix-Aware History Search (`Up` / `Down` Arrow Keys)

## Purpose
Replaces standard sequential history cycling with prefix-aware substring history traversal. Typing the beginning of any command and pressing the `Up` or `Down` arrow keys filters your shell history strictly for past commands that began with that exact prefix.

## Implementation Details

### Configuration File Modified
* [~/.zshrc](file:///home/sanjith/.zshrc)

### Code Added
```zsh
# Prefix-aware history search with Up / Down arrow keys
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
[[ -n "${terminfo[kcuu1]}" ]] && bindkey -- "${terminfo[kcuu1]}" up-line-or-beginning-search
[[ -n "${terminfo[kcud1]}" ]] && bindkey -- "${terminfo[kcud1]}" down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[OA' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search
bindkey '^[OB' down-line-or-beginning-search
```

## Usage
* **Filtered History Search**:
  Type `git` and press `Up`. It cycles through `git status`, `git commit -m ...`, `git pull`, etc., skipping all non-git commands.
* **Standard History Search**:
  Leave the prompt empty and press `Up` / `Down` to browse commands sequentially as usual.
