# `explain` — AI Shell Error Diagnostician (`Alt+E`)

## Purpose
After any command fails, press **`Alt+E`** to pipe the last command and its exit code into Antigravity (`agy`) for an instant AI explanation and suggested fix. Works entirely inside the terminal — no browser, no copy-paste.

## Usage

```bash
some-failing-command   # exits with non-zero
# Press Alt+E
# → 🔍 Diagnosing: some-failing-command (exit 127)
# → AI explanation + "Fix: <corrected command>"
```

Or call directly:
```bash
explain
```

## Architecture

- `_track_exit_precmd` hook (added via `add-zsh-hook`) records `$?` before the prompt redraws.
- `_explain-widget` is a ZLE widget bound to `Alt+E` (`^[e`).
- The widget reads `$_last_command` (set by `_notify_preexec`) and `$_last_exit_code`.
- Constructs a structured prompt and pipes it to `agy chat --model flash --no-interactive`.
- Uses Gemini Flash for sub-second latency (no separate API key needed).

## Fallback (no `agy`)
Prints suggested alternatives: `tldr <cmd>`, `man <cmd>`, `<cmd> --help | head -30`.

## Where It Lives
- Added to `dotfiles/.zshrc` — Section 14

## Dependencies
- `agy` (Antigravity CLI — preferred)
- `fzf` (optional, for future inline edit mode)
- No external API key required if `agy` is already authenticated
