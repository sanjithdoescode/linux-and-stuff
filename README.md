# Omarchy Customizations & Workflow Enhancements

This directory documents all custom configurations, shell functions, keyboard shortcuts, and plugins configured for your Omarchy Hyprland setup.

## Documentation Index

1. [**Yazi Directory Traversal on Exit (`y`)**](yazi-cwd.md)
   Shell wrapper function that changes your working directory to where you navigated inside Yazi when you exit.
2. [**Neovim Quick Alias (`n`)**](neovim-alias.md)
   Streamlined alias mapping `n` to `nvim`.
3. [**FZF Previews with Bat and Eza**](fzf-previews.md)
   Interactive `Ctrl+T` (file search with syntax highlighting) and `Alt+C` (directory jumping with tree preview).
4. [**Modern CLI Tool Aliases & Manpager**](modern-cli-aliases.md)
   Productivity aliases for `bat` (`cat` / `MANPAGER`), `lazygit` (`lg`), `lazydocker` (`ld`), `dua-cli` (`du`), and `rg`.
5. [**Interactive In-File Search (`fif` / `rgf`)**](fif-file-search.md)
   Live ripgrep searching powered by FZF with line previews and direct jump into Neovim at the exact line number.
6. [**Smart Navigation & Friction Removers**](smart-navigation.md)
   Zoxide frecency `cd`, interactive `zz`/`zd` directory picker, `AUTO_PUSHD` directory stack (`cd -<Tab>`), and `zsh-autopair`.
7. [**Interactive Tab Completion (`fzf-tab`)**](fzf-tab.md)
   Replaces Zsh's default text menu with a floating interactive FZF popup with context-aware previews.
8. [**Ghostty Dropdown Terminal & Theme Sync**](ghostty-enhancements.md)
   Global Quake-style dropdown scratchpad terminal (`Super + ` ` `) and dynamic Omarchy theme palette synchronization.
9. [**Hyprland Shortcuts: Voxtype & Screen OCR**](hyprland-shortcuts.md)
   Voice-to-text dictation (`Super + H`) and rectangle OCR text grabber (`Super + Shift + T`).
10. [**Magic Sudo Toggle (`Esc Esc` / `Alt-s`)**](magic-sudo.md)
    Toggle `sudo` on current command or quickly re-run last failed command with root privileges.
11. [**Prefix-Aware History Search**](history-search.md)
    Cycle through command history matching typed prefix using Up and Down arrow keys.
12. [**Universal Archive Extractor (`extract`)**](universal-extract.md)
    Unified archive decompressor automatically supporting `.tar.*`, `.zip`, `.7z`, `.rar`, and `.zst`.
13. [**Wayland Clipboard Helpers (`copypath` & `copyfile`)**](clipboard-helpers.md)
    Direct integration with `wl-copy` to copy absolute file paths and file contents to clipboard.
14. [**Interactive Process Killer (`fkill`)**](process-killer.md)
    Fuzzy process manager with preview pane, multi-selection, `SIGTERM` (Enter), and `SIGKILL` (Ctrl+X).
15. [**Auto Desktop Notifications for Long Commands**](long-command-alerts.md)
    Sends a desktop notification when background tasks exceeding 10s finish, showing elapsed time and exit code.
16. [**Dynamic Ghostty Tab & Window Renaming**](ghostty-dynamic-titles.md)
    Automatically updates terminal titles with active commands and current working directory paths.
17. [**Interactive Cheatsheet Explorer (`ftldr`)**](tldr-cheatsheet-explorer.md)
    Fuzzy-search 7,400+ `tldr` cheatsheets with live markdown syntax-highlighted examples.
18. [**Global Pipe Aliases (`alias -g`)**](global-pipe-aliases.md)
    Single-letter pipeline shortcuts anywhere on the command line (`C` for clipboard, `L` for bat, `G` for ripgrep, `J` for jq).
19. [**Interactive Port & Socket Inspector and Killer (`fport`)**](fport-killer.md)
    Scan listening TCP/UDP ports with process preview and instant one-key termination (`Ctrl + X`).
20. [**Instant Personal Notes & Scratchpad TUI (`fnote`)**](fnote-knowledge-base.md)
    Fuzzy markdown notes manager with live syntax previews, Neovim editing, and instant note creation (`Ctrl + N`).
21. [**Wayland Clipboard History Picker (`fclip` & `fpaste`)**](fclip-clipboard-history.md)
    Search past clipboard history with syntax previews, restore clips, and paste inline via `Alt + P`.
22. [**Interactive File Search TUI (`Ctrl + T`) & FZF Shortcuts**](ctrl-t-file-picker.md)
    Fuzzy file search with bat preview, buffer insertion, and FZF companion shortcuts (`Ctrl + R`, `**<Tab>`).
23. [**Hyprland Relative Workspace Navigation & Input Customizations**](hyprland-workspace-navigation.md)
    `Super + Left` / `Super + Right` relative workspace cycling, natural scrolling, and 8px window rounding.
24. [**Ghostty Performance Tuning & Custom Keybindings**](ghostty-terminal-tuning.md)
    Hyprland epoll async backend, CSI-u Enter encoding for TUIs, 100px split resizing, and explicit Zsh default shell.
25. [**Shell Quality of Life Options & Productivity Aliases**](shell-convenience-options.md)
    `AUTO_CD`, typo auto-correction (`CORRECT`), `:q` terminal exit, and `agyyolo` alias.
