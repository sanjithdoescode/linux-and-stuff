# `gcai` — AI Semantic Git Commit Generator

## Purpose
Generate a [Conventional Commits](https://www.conventionalcommits.org/)-formatted message from your staged diff using Antigravity AI (`agy`), review it in an `fzf` panel, and commit — all without leaving the terminal.

## Usage

```bash
git add <files>    # stage your changes
gcai               # generate, review, and commit
gcai --amend       # amend the last commit message
```

## Workflow

1. Verifies staged changes exist (`git diff --cached --stat`)
2. Pipes the diff (capped at 300 lines) into `agy chat --model flash`
3. Extracts the first line matching `^(feat|fix|docs|...):` from the response
4. Opens `fzf` with the generated message pre-filled — type to edit inline
5. Runs `git commit -m "<final_message>"`

## Message Format

```
<type>(<scope>): <description>
```

Types: `feat` | `fix` | `docs` | `style` | `refactor` | `test` | `chore` | `ci` | `perf`

## Fallback Chain

| Condition | Behaviour |
|---|---|
| `agy` available | Uses Gemini Flash — fastest, no extra setup |
| `ollama` available | Uses `llama3.2:3b` local model |
| Neither available | Prompts manually via `gum input` or `read` |

## Where It Lives
- Added to `dotfiles/.zshrc` — Section 15

## Dependencies
- `git`, `fzf`
- `agy` (preferred) or `ollama` or `gum`
