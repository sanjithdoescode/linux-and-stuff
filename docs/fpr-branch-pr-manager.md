# `fpr` — Interactive Git Branch & PR Manager

## Purpose
A unified `fzf` TUI that lists all local and remote branches with commit log previews and exposes single-key actions: checkout, merge, delete, push+open PR, and rebase. Faster than `lazygit` for simple branch operations.

## Usage

```bash
fpr
```

### Keybindings (inside fzf)

| Key | Action |
|---|---|
| `Enter` | Checkout selected branch |
| `Ctrl-M` | Merge selected branch into current |
| `Ctrl-D` | Delete selected branch (tries `-d` then `-D`) |
| `Ctrl-P` | Push current branch + open PR creation URL in browser |
| `Ctrl-R` | Rebase current branch onto selected |
| `Ctrl-/` | Toggle git log preview pane |

## Branch List Format

```
<branch-name>         <ahead N behind M>  <last commit subject>
```

Remote branches show with their full `remotes/origin/` prefix; checkout strips it automatically.

## PR URL Construction (`Ctrl-P`)

1. If `gh` (GitHub CLI) is installed: `gh pr create --web`
2. GitHub remote: `https://github.com/<org>/<repo>/compare/<branch>?expand=1`
3. GitLab remote: `https://gitlab.com/<org>/<repo>/-/merge_requests/new?...`

## Where It Lives
- Added to `dotfiles/.zshrc` — Section 16

## Dependencies
- `git`, `fzf`
- Optional: `gh` (GitHub CLI for `gh pr create`)
