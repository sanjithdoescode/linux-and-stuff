# 🚀 Omarchy Linux Dotfiles & Custom Enhancements

[![OS: Arch Linux](https://img.shields.io/badge/OS-Arch%20Linux-1793d1?logo=arch-linux&logoColor=white)](https://archlinux.org)
[![WM: Hyprland](https://img.shields.io/badge/WM-Hyprland-00acc1?logo=wayland&logoColor=white)](https://hyprland.org)
[![Shell: Zsh](https://img.shields.io/badge/Shell-Zsh-black?logo=gnu-bash&logoColor=white)](https://zsh.sourceforge.io)
[![Editor: Neovim](https://img.shields.io/badge/Editor-Neovim-57A143?logo=neovim&logoColor=white)](https://neovim.io)
[![Terminal: Ghostty](https://img.shields.io/badge/Terminal-Ghostty-orange)](https://ghostty.org)
[![Docs: 27 Guides](https://img.shields.io/badge/Documentation-27%20Guides-blueviolet)](docs/README.md)

Welcome to my personal public repository of **Omarchy Linux** dotfiles, desktop customizations, terminal tuning, and interactive productivity micro-TUIs.

This repository serves two primary purposes:
1. **Complete Dotfiles Management**: Houses production configuration files for Hyprland, Zsh, Ghostty, Kitty, Neovim, Tmux, Starship, custom Omarchy plugins, themes, and power profiles.
2. **Comprehensive Documentation**: Contains 27 standalone deep-dive guides explaining every workflow enhancement, custom shell function, keyboard shortcut, and micro-TUI.

> 📖 **Looking for the deep-dive feature guides?**  
> Check out the [**Documentation Index (docs/README.md)**](docs/README.md) for 27 step-by-step guides with examples, keybindings, and architectural notes.

---

## 📑 Table of Contents

- [Repository Structure](#-repository-structure)
- [Dotfiles & Configurations](#-dotfiles--configurations)
  - [Shell & Terminal Environment](#shell--terminal-environment)
  - [Hyprland & Desktop Ecosystem](#hyprland--desktop-ecosystem)
  - [Editors & Core Utilities](#editors--core-utilities)
  - [Omarchy Custom Plugins & Themes](#omarchy-custom-plugins--themes)
- [Highlighted Features & Micro-TUIs](#-highlighted-features--micro-tuis)
- [Installation & Deployment](#-installation--deployment)
  - [Automated Deployment (`install.sh`)](#automated-deployment-installsh)
  - [Using GNU Stow](#using-gnu-stow)
  - [Installing External Plugins & Themes](#installing-external-plugins--themes)
- [Dependencies & Prerequisites](#-dependencies--prerequisites)
- [Documentation Index](#-documentation-index)

---

## 📁 Repository Structure

```
.
├── dotfiles/                    # Home directory mapping tree
│   ├── .zshrc                   # Full interactive Zsh config with micro-TUIs
│   ├── .bashrc                  # Bash interactive fallback config
│   ├── .bash_profile           # Bash login profile
│   ├── .profile                # POSIX login profile
│   ├── .tmux.conf              # Tmux default configuration
│   ├── .XCompose               # Custom compose key emojis and snippets
│   ├── .config/
│   │   ├── alacritty/          # Alacritty terminal config with CSI-u keys
│   │   ├── autostart/          # XDG autostart desktop entries
│   │   ├── btop/               # Btop system monitor theme and config
│   │   ├── fcitx5/             # Fcitx5 input method configuration
│   │   ├── foot/               # Foot terminal emulator config
│   │   ├── ghostty/            # Ghostty config (Quake drop-down, CSI-u, epoll)
│   │   ├── git/                # Git user config, rebase rules, and gh helpers
│   │   ├── gtk-3.0/            # GTK file picker bookmarks
│   │   ├── helix/              # Helix modal editor config
│   │   ├── hypr/               # Hyprland configs (bindings, looknfeel, input)
│   │   ├── hyprland-preview-share-picker/  # Screen-sharing picker
│   │   ├── imv/                # Lightweight Wayland image viewer config
│   │   ├── kitty/              # Kitty terminal config with theme integration
│   │   ├── lazygit/            # Lazygit configuration
│   │   ├── mise/               # Mise tool manager configuration
│   │   ├── nvim/               # Complete Neovim configuration (LazyVim + Antigravity AI sidebar)
│   │   ├── omarchy/            # Custom Omarchy shell configs, hooks, & plugins
│   │   │   ├── branding/       # Custom ASCII branding & screensavers
│   │   │   ├── defaults/       # Default agent & app overrides
│   │   │   ├── extensions/     # Omarchy menu extension JSONC
│   │   │   ├── hooks/          # Lifecycle hooks (post-update, battery-low)
│   │   │   ├── plugins/        # Custom plugins (sanjith.power)
│   │   │   ├── themes/         # Custom Aether-generated themes (hrc, mm93)
│   │   │   └── backgrounds/    # Custom desktop wallpapers
│   │   ├── starship.toml       # Minimal, fast prompt configuration
│   │   ├── tensaku/            # Tensaku screenshot annotation config
│   │   ├── tmux/               # Advanced tmux session and pane management
│   │   ├── voxtype/            # Whisper voice-to-text dictation daemon config
│   │   ├── wireplumber/        # PipeWire / WirePlumber Bluetooth auto-connect
│   │   ├── chromium-flags.conf # Wayland ozone flags & Omarchy browser extensions
│   │   ├── brave-origin-flags.conf # Brave browser Wayland flags
│   │   ├── mimeapps.list       # XDG default application associations
│   │   ├── user-dirs.dirs      # XDG user directory mappings
│   │   └── xdg-terminals.list  # Terminal emulator priority list
│   └── .local/
│       └── bin/                # Custom utility scripts & Antigravity CLI symlink
├── docs/                       # 27 standalone markdown documentation guides
│   ├── README.md               # Complete documentation catalog
│   ├── agents/                 # Antigravity agent customization guide
│   └── *.md                    # Individual deep dives for every workflow tool
├── install.sh                  # Safe installer (symlink, copy, dry-run, backup)
└── README.md                   # Main repository overview (this file)
```

---

## ⚙️ Dotfiles & Configurations

### Shell & Terminal Environment

- **[Zsh (`dotfiles/.zshrc`)](docs/shell-convenience-options.md)**:
  - Enabled with `AUTO_CD`, auto-correction (`CORRECT`), and directory history stack (`AUTO_PUSHD`).
  - Seamless fuzzy completions powered by **`fzf-tab`** with context-aware previews.
  - Interactive history navigation matching typed prefixes via Up/Down arrow keys.
  - Global pipe aliases (`C` for `wl-copy`, `L` for `bat`, `G` for `ripgrep`, `J` for `jq`).
  - Automatic background desktop notifications for long-running commands (>10s).
- **[Ghostty (`dotfiles/.config/ghostty/config`)](docs/ghostty-terminal-tuning.md)**:
  - Dropdown Quake scratchpad terminal toggled globally with `Super + ` ` ` ([docs](docs/ghostty-enhancements.md)).
  - CSI-u key encoding (`Shift+Enter` and `Alt+Shift+Enter`) for clean TUI key handling.
  - Hyprland `async-backend = epoll` rendering optimization.
  - 100px split resizing shortcuts and automatic Omarchy theme sync.
- **[Kitty, Alacritty, and Foot](docs/ghostty-enhancements.md)**:
  - Unified color theme loading from `~/.local/state/omarchy/current/theme/`.
  - JetBrainsMono Nerd Font @ 11pt, clean padding, and consistent clipboard shortcuts.
- **[Tmux (`dotfiles/.config/tmux/tmux.conf`)](dotfiles/.config/tmux/tmux.conf)**:
  - Space prefix (`Ctrl + Space`), vi-mode copy buffer, popup keybinding cheatsheets.

### Hyprland & Desktop Ecosystem

- **[Bindings (`dotfiles/.config/hypr/bindings.lua`)](docs/hyprland-shortcuts.md)**:
  - `Super + H`: Toggle Voxtype voice-to-text dictation.
  - `Super + Shift + T`: Interactive screen OCR text grabber to Wayland clipboard.
  - `Super + Left` / `Super + Right`: Relative workspace navigation cycling ([docs](docs/hyprland-workspace-navigation.md)).
- **[Input & Look-and-Feel](docs/hyprland-workspace-navigation.md)**:
  - Natural touchpad scrolling enabled (`natural_scroll = true`).
  - Window decoration tuned with 8px subtle corner rounding.
- **[WirePlumber Audio Fix](dotfiles/.config/wireplumber/wireplumber.conf.d/bluetooth-a2dp-autoconnect.conf)**:
  - Automatic Bluetooth A2DP audio sink/source profile recovery for headsets and speakers.

### Editors & Core Utilities

- **[Neovim (`dotfiles/.config/nvim/`)](docs/neovim-alias.md)**:
  - LazyVim modular configuration with dynamic Omarchy theme hot-reloading (`lua/plugins/omarchy-theme-hotreload.lua`).
  - **Antigravity AI Assistant Sidebar (`lua/plugins/antigravity.lua`)**: Right-side AI pair programming companion powered by [`antigravity-cli.nvim`](https://github.com/NakLast/antigravity-cli.nvim) by [NakLast](https://github.com/NakLast) with `<leader>ag` toggle, persistent CLI session context, and `<leader>as` code selection piping ([Guide](docs/antigravity-neovim-sidebar.md)).
  - Transparency override, remote clipboard synchronization, and animated scrolling tweaks.
- **[Starship (`dotfiles/.config/starship.toml`)](dotfiles/.config/starship.toml)**:
  - Clean, cyan-themed git status, branch tracking, and two-level directory truncation.
- **[Btop & Lazygit](docs/modern-cli-aliases.md)**:
  - Btop performance monitor preconfigured with Omarchy themes.

### Omarchy Custom Plugins & Themes

- **`sanjith.power` Plugin (`dotfiles/.config/omarchy/plugins/sanjith.power/`)**:
  - Custom Omarchy top-bar widget displaying battery health, power profiles, and charging wattage.
  - Paired with system scripts: `omarchy-powerprofiles-list` and `omarchy-powerprofiles-set`.
- **Custom Aether Themes (`dotfiles/.config/omarchy/themes/`)**:
  - **`hrc`**: Deep dark theme with indigo/violet accents.
  - **`mm93`**: Warm dark theme with golden-amber and olive accents.
- **System Update Hooks (`dotfiles/.config/omarchy/hooks/post-update.d/`)**:
  - Automatically verifies Voxtype dictation, AI agent defaults, and fingerprint reader configuration after Omarchy system upgrades.

---

## 🛠 Highlighted Features & Micro-TUIs

All custom functions and aliases are built into [`.zshrc`](dotfiles/.zshrc) and thoroughly documented in the [`docs/`](docs/) directory:

| Command / Shortcut | Description | Documentation |
| :--- | :--- | :--- |
| `fclip` / `fpaste` (`Alt+P`) | Wayland clipboard history picker with live syntax previews | [Guide](docs/fclip-clipboard-history.md) |
| `fif` / `rgf` | Live ripgrep search with bat preview & direct Neovim line jumping | [Guide](docs/fif-file-search.md) |
| `fport` | Interactive TCP/UDP port inspector with one-key termination (`Ctrl+X`) | [Guide](docs/fport-killer.md) |
| `fnote` | Instant markdown note scratchpad with search, creation (`Ctrl+N`), and edit | [Guide](docs/fnote-knowledge-base.md) |
| `fkill` | Fuzzy process manager with multi-selection and kill signals | [Guide](docs/process-killer.md) |
| `ftldr` | Interactive cheatsheet explorer for 7,400+ `tldr` community pages | [Guide](docs/tldr-cheatsheet-explorer.md) |
| `y` | Yazi wrapper that preserves navigated directory on exit | [Guide](docs/yazi-cwd.md) |
| `extract <file>` | Universal decompression for `.tar.*`, `.zip`, `.7z`, `.rar`, `.zst` | [Guide](docs/universal-extract.md) |
| `Esc Esc` / `Alt+S` | Magic sudo toggle for current or previously failed command | [Guide](docs/magic-sudo.md) |
| `Ctrl+T` / `Alt+C` | Fuzzy file search and directory navigation with Bat / Eza previews | [Guide](docs/ctrl-t-file-picker.md) |
| `copypath` / `copyfile` | Quick absolute file path and file contents copier | [Guide](docs/clipboard-helpers.md) |
| `Super + ` ` ` | Global dropdown Quake terminal scratchpad in Ghostty | [Guide](docs/ghostty-enhancements.md) |
| `Super + H` | Whisper push-to-talk voice dictation | [Guide](docs/hyprland-shortcuts.md) |
| `Super + Shift + T`| Screen rectangle OCR text grabber | [Guide](docs/hyprland-shortcuts.md) |
| `<leader>ag` / `<leader>as` | Antigravity AI Neovim right sidebar & code selection reference | [Guide](docs/antigravity-neovim-sidebar.md) |

---

## 📥 Installation & Deployment

### Automated Deployment (`install.sh`)

The repository includes an interactive, safe deployment script that creates symlinks (or copies) directly to `$HOME`:

```bash
# Clone the repository
git clone https://github.com/sanjithdoescode/omarchy_changes.git
cd omarchy_changes

# 1. Preview changes without modifying any files (Dry Run)
./install.sh --dry-run

# 2. Symlink all dotfiles into $HOME (Backs up existing files automatically)
./install.sh --link

# 3. (Optional) Also clone external Zsh plugins (fzf-tab, autopair, etc.)
./install.sh --link --plugins
```

#### Flags & Options:
- `--link` *(default)*: Symlinks files from `dotfiles/` to `$HOME`.
- `--copy`: Copies files instead of symlinking.
- `--dry-run`: Shows all planned operations without touching the disk.
- `--plugins`: Automatically fetches missing Zsh plugins into `~/.zsh/plugins/`.

> [!NOTE]  
> If an existing destination file differs from the repository version, `install.sh` will create a timestamped backup (e.g., `~/.zshrc.backup.20260918113000`) before linking.

---

### Using GNU Stow

If you prefer using [GNU Stow](https://www.gnu.org/software/stow/):

```bash
cd omarchy_changes
stow -t ~ dotfiles
```

---

### Installing External Plugins & Themes

In addition to the custom files bundled in this repo, you can install the external Omarchy themes and plugins used in this setup:

```bash
# External Omarchy Plugins
omarchy plugin add https://github.com/twiking/omasettings.git --enable
omarchy plugin add https://github.com/huacnlee/omamail.git --enable
omarchy plugin add https://github.com/Pablo-Merino/omarchy-altswitch.git
omarchy plugin add https://github.com/bobby-nicholas/omaland.git

# External Omarchy Themes
omarchy theme install https://github.com/JaxonWright/omarchy-midnight-theme
omarchy theme install https://github.com/dhh/omarchy-zonda-zoom-theme
omarchy theme install https://github.com/abhijeet-swami/omarchy-ayaka-theme
omarchy theme install https://github.com/archer-clawbot/omarchy-hermarchy-theme
```

To activate the custom included Aether themes:
```bash
omarchy theme set hrc
# or
omarchy theme set mm93
```

---

## 📦 Dependencies & Prerequisites

To utilize all micro-TUIs, shell functions, and desktop shortcuts, install the following packages on Arch Linux / Omarchy:

```bash
# Core CLI Tools & Preview Utilities
sudo pacman -S --needed \
  zsh fzf bat eza ripgrep zoxide jq fd \
  tldr wl-clipboard libnotify fastfetch btop lazygit

# Terminal & Editors
sudo pacman -S --needed ghostty neovim tmux

# Voice & OCR (Optional)
# voxtype (dictation) & tesseract / slurp / grim (OCR screen capture)
```

---

## 📚 Documentation Index

All 26 detailed markdown guides are maintained inside the [`docs/`](docs/) directory:

1. [**Yazi Directory Traversal on Exit (`y`)**](docs/yazi-cwd.md)
2. [**Neovim Quick Alias (`n`)**](docs/neovim-alias.md)
3. [**FZF Previews with Bat and Eza**](docs/fzf-previews.md)
4. [**Modern CLI Tool Aliases & Manpager**](docs/modern-cli-aliases.md)
5. [**Interactive In-File Search (`fif` / `rgf`)**](docs/fif-file-search.md)
6. [**Smart Navigation & Friction Removers**](docs/smart-navigation.md)
7. [**Interactive Tab Completion (`fzf-tab`)**](docs/fzf-tab.md)
8. [**Ghostty Dropdown Terminal & Theme Sync**](docs/ghostty-enhancements.md)
9. [**Hyprland Shortcuts: Voxtype & Screen OCR**](docs/hyprland-shortcuts.md)
10. [**Magic Sudo Toggle (`Esc Esc` / `Alt-s`)**](docs/magic-sudo.md)
11. [**Prefix-Aware History Search**](docs/history-search.md)
12. [**Universal Archive Extractor (`extract`)**](docs/universal-extract.md)
13. [**Wayland Clipboard Helpers (`copypath` & `copyfile`)**](docs/clipboard-helpers.md)
14. [**Interactive Process Killer (`fkill`)**](docs/process-killer.md)
15. [**Auto Desktop Notifications for Long Commands**](docs/long-command-alerts.md)
16. [**Dynamic Ghostty Tab & Window Renaming**](docs/ghostty-dynamic-titles.md)
17. [**Interactive Cheatsheet Explorer (`ftldr`)**](docs/tldr-cheatsheet-explorer.md)
18. [**Global Pipe Aliases (`alias -g`)**](docs/global-pipe-aliases.md)
19. [**Interactive Port & Socket Inspector and Killer (`fport`)**](docs/fport-killer.md)
20. [**Instant Personal Notes & Scratchpad TUI (`fnote`)**](docs/fnote-knowledge-base.md)
21. [**Wayland Clipboard History Picker (`fclip` & `fpaste`)**](docs/fclip-clipboard-history.md)
22. [**Interactive File Search TUI (`Ctrl + T`) & FZF Shortcuts**](docs/ctrl-t-file-picker.md)
23. [**Hyprland Relative Workspace Navigation & Input Customizations**](docs/hyprland-workspace-navigation.md)
24. [**Ghostty Performance Tuning & Custom Keybindings**](docs/ghostty-terminal-tuning.md)
25. [**Shell Quality of Life Options & Productivity Aliases**](docs/shell-convenience-options.md)
26. [**Antigravity Agent Customization System**](docs/agents/agy.md)
27. [**Antigravity AI Assistant Neovim Sidebar**](docs/antigravity-neovim-sidebar.md)

---

## 👤 Author

**Sanjith**  
GitHub: [@sanjithdoescode](https://github.com/sanjithdoescode)
