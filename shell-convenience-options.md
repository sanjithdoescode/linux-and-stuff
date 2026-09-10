# Shell Quality of Life Options & Productivity Aliases

## Purpose
Documents native Zsh options and daily friction-removing aliases configured across `~/.zshrc` and `~/.bashrc`.

## Implementation Details

### Configuration Files Modified
* [~/.zshrc](file:///home/sanjith/.zshrc)
* [~/.bashrc](file:///home/sanjith/.bashrc)

### 1. Frictionless Navigation & Typo Correction ([~/.zshrc](file:///home/sanjith/.zshrc))
```zsh
setopt AUTO_CD   # Type directory name directly to cd into it
setopt CORRECT   # Intelligent command spell-check and auto-correction
```

* **`AUTO_CD`**: Simply typing `Projects`, `..`, or `Downloads` without `cd` navigates directly into that directory.
* **`CORRECT`**: Catches mistyped shell commands (e.g. typing `sl` prompts `zsh: correct 'sl' to 'ls' [nyae]?`).

### 2. Muscle Memory & Workflow Aliases
```zsh
# Fast terminal exit (Vim muscle-memory)
alias :q='exit'

# Antigravity CLI without repeated permission prompts
alias agyyolo='agy --dangerously-skip-permissions'

# Helix editor shortcut (in ~/.bashrc)
alias hx="helix"
```

## Quick Summary

| Option / Alias | Behavior |
| :--- | :--- |
| **`AUTO_CD`** | Type any path (e.g. `Projects`) to jump into it immediately |
| **`CORRECT`** | Prompts to correct command typos before execution |
| **`:q`** | Closes the terminal tab or pane |
| **`agyyolo`** | Launches Antigravity CLI with `--dangerously-skip-permissions` |
| **`hx`** | Launches Helix editor |
