# Smart Navigation & Friction Removers

## Purpose
Streamlines directory jumping and command-line typing:
1. Replaces standard `cd` with **Zoxide**'s frecency algorithm while keeping native functionality.
2. Adds directory stack tracking so you can jump back to recent directories with `cd -<Tab>`.
3. Adds **`zsh-autopair`** to automatically complete quotes and brackets.

## Implementation Details

### Plugins Installed
* [~/.zsh/plugins/zsh-autopair](file:///home/sanjith/.zsh/plugins/zsh-autopair) (cloned from `https://github.com/hlissner/zsh-autopair`)

### Configuration File Modified
* [~/.zshrc](file:///home/sanjith/.zshrc)

### Code Added
```zsh
# Environment tools (Zoxide with --cmd cd)
command -v zoxide &>/dev/null && eval "$(zoxide init zsh --cmd cd)"

# Quality of Life Options
setopt AUTO_CD                # Just type a directory name to CD into it
setopt CORRECT                # Spell check commands (suggests corrections)
setopt AUTO_PUSHD             # Push old directory onto stack on cd (enables cd -<Tab>)
setopt PUSHD_IGNORE_DUPS      # Do not store duplicates in the stack
setopt PUSHD_SILENT           # Do not print directory stack after pushd/popd

# zsh-autopair (Auto-close brackets and quotes)
if [ -f ~/.zsh/plugins/zsh-autopair/autopair.zsh ]; then
    source ~/.zsh/plugins/zsh-autopair/autopair.zsh
    autopair-init
fi

# Interactive zoxide directory jump with eza tree preview
if command -v zoxide &>/dev/null; then
    alias z="cd"
    zz() {
        local dir
        dir=$(zoxide query -l | fzf --preview 'eza --tree --color=always {} 2>/dev/null | head -200' --preview-window=right:60% --header 'Jump to directory (Enter: cd)') && [ -n "$dir" ] && cd "$dir"
    }
    alias zd="zz"
fi
```

## Features

1. **Smart `cd`**:
   * Type `cd <part-of-name>` (e.g. `cd doc`) to jump directly to `~/Documents`.
   * Standard `cd ..`, `cd -`, or absolute/relative paths continue to work normally.
2. **Directory Tree Jump (`zz` / `zd`)**:
   * Run `zz` or `zd` to bring up a fuzzy list of all your frequent directories with a live `eza` tree view on the right.
3. **Directory History Stack (`cd -<Tab>`)**:
   * Every directory change is remembered in the Zsh dirstack.
   * Type `cd -` and press `<Tab>` to see a numbered history of your previous locations.
4. **Auto-pairing**:
   * Typing `(`, `[`, `{`, `"`, or `'` automatically inserts the closing pair.
