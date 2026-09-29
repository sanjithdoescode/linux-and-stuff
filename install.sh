#!/usr/bin/env bash
#
# ==============================================================================
#                      OMARCHIT - THE SANJITH WAY
#             Dotfiles & Workspace Suite Installer
# ==============================================================================
# Interactive TUI Installer with automatic Linux distribution detection,
# package prerequisite installation, granular component selection, safe
# automatic backups, and live installation progress tracking.
#
# Usage:
#   ./install.sh                # Launch interactive TUI
#   ./install.sh --link         # Deploy using symlinks (default)
#   ./install.sh --copy         # Deploy by copying files
#   ./install.sh --dry-run      # Preview installation without modifications
#   ./install.sh --plugins      # Clone external Zsh plugins
#   ./install.sh --prereqs      # Install system packages for detected distro
#   ./install.sh --all -y       # Non-interactive complete installation
#   ./install.sh --no-tui       # Run in non-interactive batch mode
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$SCRIPT_DIR/dotfiles"
TARGET_DIR="${HOME}"

# Runtime State
MODE="link"          # "link" or "copy"
DRY_RUN=false
RUN_TUI=true
NON_INTERACTIVE=false
INSTALL_PLUGINS_CLI=false
INSTALL_PREREQS_CLI=false

# Terminal Capabilities
IS_TTY=false
if [ -t 0 ] && [ -t 1 ]; then
    IS_TTY=true
fi

# ANSI Colors & Formatting
BOLD=$'\033[1m'
DIM=$'\033[2m'
ITALIC=$'\033[3m'
UNDERLINE=$'\033[4m'
RESET=$'\033[0m'

# Palette
C_PRIMARY=$'\033[38;5;51m'     # Bright Cyan / Neon Blue
C_ACCENT=$'\033[38;5;141m'     # Soft Purple / Lavender
C_GREEN=$'\033[38;5;82m'       # Vibrant Green
C_YELLOW=$'\033[38;5;214m'     # Amber / Gold
C_RED=$'\033[38;5;203m'        # Soft Coral Red
C_GRAY=$'\033[38;5;244m'       # Medium Gray
C_DARK_GRAY=$'\033[38;5;238m'  # Border Gray
C_WHITE=$'\033[38;5;255m'      # Pure White
C_BG_HIGHLIGHT=$'\033[48;5;236m' # Selection background

# Performance & Display Pre-allocations
NL=$'\n'
CLR_EOL=$'\033[K'
SPACES="                                                                                                                                                                                                        "
ANSI_RE=$'\x1b\\[[0-9;]*[a-zA-Z]'
PROGRESS_FILLED="████████████████████████████████████████"
PROGRESS_EMPTY="░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░"
BOX_W=74
INNER_W=72
HLINE=""

# Logger fallbacks for batch / non-TUI mode
log_info() { echo -e "${C_PRIMARY}[INFO]${RESET} $*"; }
log_success() { echo -e "${C_GREEN}[OK]${RESET} $*"; }
log_warn() { echo -e "${C_YELLOW}[WARN]${RESET} $*"; }
log_err() { echo -e "${C_RED}[ERROR]${RESET} $*"; }

# ------------------------------------------------------------------------------
# Distribution & Package Manager Detection
# ------------------------------------------------------------------------------
DISTRO_ID="unknown"
DISTRO_NAME="Unknown Linux"
DISTRO_FAMILY="unknown"
PKG_MGR="unknown"
PKG_FAMILY="unknown"

detect_distribution() {
    if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        DISTRO_ID="${ID:-unknown}"
        DISTRO_NAME="${PRETTY_NAME:-${NAME:-Linux}}"
        DISTRO_FAMILY="${ID_LIKE:-$DISTRO_ID}"
    elif [ "$(uname -s)" = "Darwin" ]; then
        DISTRO_ID="darwin"
        DISTRO_NAME="macOS $(sw_vers -productVersion 2>/dev/null || echo '')"
        DISTRO_FAMILY="darwin"
    fi

    # Determine Package Manager & Family
    case "$DISTRO_ID" in
        arch|omarchy|manjaro|endeavouros|garuda|artix|cachyos|arcolinux)
            PKG_MGR="pacman"
            PKG_FAMILY="arch"
            ;;
        ubuntu|debian|pop|linuxmint|elementary|kali|raspbian|neon)
            PKG_MGR="apt"
            PKG_FAMILY="debian"
            ;;
        fedora|rhel|centos|almalinux|rocky|nobara)
            PKG_MGR="dnf"
            PKG_FAMILY="fedora"
            ;;
        opensuse*|sles|tumbleweed|leap)
            PKG_MGR="zypper"
            PKG_FAMILY="suse"
            ;;
        void)
            PKG_MGR="xbps"
            PKG_FAMILY="void"
            ;;
        alpine)
            PKG_MGR="apk"
            PKG_FAMILY="alpine"
            ;;
        gentoo)
            PKG_MGR="emerge"
            PKG_FAMILY="gentoo"
            ;;
        darwin)
            PKG_MGR="brew"
            PKG_FAMILY="darwin"
            ;;
        *)
            # Check ID_LIKE family
            case "${DISTRO_FAMILY}" in
                *arch*)
                    PKG_MGR="pacman"
                    PKG_FAMILY="arch"
                    ;;
                *debian*|*ubuntu*)
                    PKG_MGR="apt"
                    PKG_FAMILY="debian"
                    ;;
                *fedora*|*rhel*)
                    PKG_MGR="dnf"
                    PKG_FAMILY="fedora"
                    ;;
                *suse*)
                    PKG_MGR="zypper"
                    PKG_FAMILY="suse"
                    ;;
                *)
                    # Fallback binary inspection
                    if command -v pacman >/dev/null 2>&1; then
                        PKG_MGR="pacman"
                        PKG_FAMILY="arch"
                    elif command -v apt-get >/dev/null 2>&1; then
                        PKG_MGR="apt"
                        PKG_FAMILY="debian"
                    elif command -v dnf >/dev/null 2>&1; then
                        PKG_MGR="dnf"
                        PKG_FAMILY="fedora"
                    elif command -v zypper >/dev/null 2>&1; then
                        PKG_MGR="zypper"
                        PKG_FAMILY="suse"
                    elif command -v xbps-install >/dev/null 2>&1; then
                        PKG_MGR="xbps"
                        PKG_FAMILY="void"
                    elif command -v apk >/dev/null 2>&1; then
                        PKG_MGR="apk"
                        PKG_FAMILY="alpine"
                    elif command -v brew >/dev/null 2>&1; then
                        PKG_MGR="brew"
                        PKG_FAMILY="darwin"
                    fi
                    ;;
            esac
            ;;
    esac
}

detect_distribution

# ------------------------------------------------------------------------------
# Module Definitions & Mapping
# ------------------------------------------------------------------------------
# Keys:
# prereqs, zsh, zsh_plugins, bash, ghostty, terminals, tmux, nvim,
# helix, git_tools, btop, hyprland, desktop_media, desktop_common,
# omarchy_core, powerprofiles, antigravity

MODULE_KEYS=(
    "prereqs"
    "zsh"
    "zsh_plugins"
    "bash"
    "ghostty"
    "terminals"
    "tmux"
    "nvim"
    "helix"
    "git_tools"
    "btop"
    "hyprland"
    "desktop_media"
    "desktop_common"
    "omarchy_core"
    "powerprofiles"
    "antigravity"
)

declare -A MODULE_NAMES=(
    ["prereqs"]="System Prerequisites"
    ["zsh"]="Zsh Shell & Starship"
    ["zsh_plugins"]="External Zsh Plugins"
    ["bash"]="Bash Fallback & Profiles"
    ["ghostty"]="Ghostty Terminal"
    ["terminals"]="Kitty, Alacritty & Foot"
    ["tmux"]="Tmux Multiplexer"
    ["nvim"]="Neovim IDE (LazyVim + AI)"
    ["helix"]="Helix Modal Editor"
    ["git_tools"]="Git, Lazygit & Mise"
    ["btop"]="Btop System Monitor"
    ["hyprland"]="Hyprland Ecosystem"
    ["desktop_media"]="Audio, Media & Dictation"
    ["desktop_common"]="Desktop & Wayland Settings"
    ["omarchy_core"]="Omarchy Core & Themes"
    ["powerprofiles"]="Power Profiles & Udev"
    ["antigravity"]="Antigravity AI CLI"
)

declare -A MODULE_TAGS=(
    ["prereqs"]="Packages"
    ["zsh"]="Shell"
    ["zsh_plugins"]="Shell"
    ["bash"]="Shell"
    ["ghostty"]="Terminal"
    ["terminals"]="Terminal"
    ["tmux"]="Terminal"
    ["nvim"]="Editor"
    ["helix"]="Editor"
    ["git_tools"]="DevTools"
    ["btop"]="Monitor"
    ["hyprland"]="Desktop"
    ["desktop_media"]="Media"
    ["desktop_common"]="Desktop"
    ["omarchy_core"]="Omarchy"
    ["powerprofiles"]="Hardware"
    ["antigravity"]="AI CLI"
)

declare -A MODULE_DESCS=(
    ["prereqs"]="Detects $DISTRO_NAME and installs packages via $PKG_MGR"
    ["zsh"]="Interactive .zshrc, micro-TUIs (fif, fkill, fnote, fclip), ~/.config/zsh, & starship.toml"
    ["zsh_plugins"]="Clones fzf-tab, zsh-autosuggestions, syntax-highlighting & autopair to ~/.zsh"
    ["bash"]="Fallback interactive configs: .bashrc, .bash_profile, and .profile"
    ["ghostty"]="Drop-down Quake terminal, CSI-u, epoll event loop, and theme synchronization"
    ["terminals"]="Modern terminal configs with CSI-u keys (Kitty, Alacritty, Foot)"
    ["tmux"]="Tmux multiplexer config, pane split navigation, and ~/.config/tmux setup"
    ["nvim"]="LazyVim setup with Antigravity AI Neovim sidebar, theme hotreload & LSP"
    ["helix"]="Helix modal text editor configuration and custom Omarchy color theme"
    ["git_tools"]="Git config & rebase helpers, Lazygit layout, and Mise runtime version manager"
    ["btop"]="Btop system resource monitor configuration and custom theme"
    ["hyprland"]="Hyprland window manager, Lua keybindings, and screen sharing preview picker"
    ["desktop_media"]="PipeWire WirePlumber BT auto-connect, IMV, Tensaku OCR, Voxtype dictation"
    ["desktop_common"]="XDG autostart, fcitx5 input method, GTK bookmarks, MIME apps & browser flags"
    ["omarchy_core"]="Custom Omarchy shell settings, hooks, branding, and Aether themes (hrc, mm93)"
    ["powerprofiles"]="ACPI platform_profile switcher scripts and /etc/udev/rules.d hardware rule"
    ["antigravity"]="Google Antigravity AI coding assistant CLI launcher (~/.local/bin/antigravity-cli)"
)

declare -A MODULE_EXCLUSIVITIES=(
    ["prereqs"]="Cross-Distro Core (Arch, Fedora, Debian)"
    ["zsh"]="Cross-Distro + Omarchy Micro-TUIs"
    ["zsh_plugins"]="Cross-Distro Compatible"
    ["bash"]="Cross-Distro Compatible"
    ["ghostty"]="Cross-Distro (Omarchy / Arch Native)"
    ["terminals"]="Cross-Distro Compatible"
    ["tmux"]="Cross-Distro Compatible"
    ["nvim"]="Omarchy Enhanced + AI Integration"
    ["helix"]="Cross-Distro + Omarchy Aether Themes"
    ["git_tools"]="Cross-Distro Compatible"
    ["btop"]="Cross-Distro + Omarchy Custom Palette"
    ["hyprland"]="★ OMARCHY & ARCH WAYLAND NATIVE"
    ["desktop_media"]="★ OMARCHY OPTIMIZED (PipeWire / Wayland)"
    ["desktop_common"]="Cross-Distro Wayland Desktop"
    ["omarchy_core"]="★ OMARCHY EXCLUSIVE (Core Shell & Themes)"
    ["powerprofiles"]="★ OMARCHY & LAPTOP HARDWARE EXCLUSIVE"
    ["antigravity"]="Omarchy AI Suite"
)

declare -a DET_BENEFITS=()
declare -a DET_ASSETS=()
declare -a DET_DISTRO=()

get_module_info() {
    local k="$1"
    DET_BENEFITS=()
    DET_ASSETS=()
    DET_DISTRO=()

    case "$k" in
        prereqs)
            DET_BENEFITS=(
                "Installs modern, high-speed CLI toolchains for $DISTRO_NAME via $PKG_MGR"
                "Fast CLI replacements: eza (ls), bat (cat), ripgrep (grep), fd (find), zoxide (cd)"
                "Developer essentials: neovim, tmux, git, curl, jq, fastfetch, btop system monitor"
                "Wayland ecosystem tools: wl-clipboard (clipboard sync), libnotify (desktop alerts)"
            )
            DET_ASSETS=(
                "System package manager packages: ${PKG_MGR}"
                "~/.local/bin/ (compatibility symlinks for batcat and fdfind on Debian/Ubuntu)"
            )
            DET_DISTRO=(
                "Arch / Omarchy: Native pacman repos (zsh, fzf, bat, eza, ripgrep, etc.)"
                "Fedora: Native dnf packages (dnf install zsh, bat, eza, ripgrep, etc.)"
                "Debian / Ubuntu: Native apt packages + automatic batcat/fdfind PATH symlinks"
            )
            ;;
        zsh)
            DET_BENEFITS=(
                "Interactive .zshrc: Zero-latency startup with optimized asynchronous completions"
                "Starship Prompt (~/.config/starship.toml): Git status, execution timer, directory path"
                "Micro-TUI fif: Live ripgrep fuzzy file search with syntax-highlighted bat preview"
                "Micro-TUI fkill: Visual process killer displaying PID, CPU, memory, and signals"
                "Micro-TUI fnote: Instant markdown notes manager and knowledge base explorer"
                "Micro-TUI fclip: Wayland clipboard history browser and fuzzy paste helper"
            )
            DET_ASSETS=(
                "~/.zshrc, ~/.config/zsh/, ~/.config/starship.toml"
                "~/.config/zsh/functions/ (fif, fkill, fnote, fclip micro-TUIs)"
            )
            DET_DISTRO=(
                "Arch / Omarchy: 100% native with full micro-TUI integration"
                "Fedora: Fully supported out of the box with dnf packages"
                "Debian: Fully supported with apt packages and bat/fd aliases"
            )
            ;;
        zsh_plugins)
            DET_BENEFITS=(
                "fzf-tab: Replaces default zsh completion with interactive fuzzy fzf menu"
                "zsh-autosuggestions: Asynchronous Fish-like suggestions as you type"
                "zsh-syntax-highlighting: Real-time syntax verification for CLI commands"
                "zsh-autopair: Automatic matching bracket, quote, and parenthesis insertion"
            )
            DET_ASSETS=(
                "~/.zsh/plugins/fzf-tab/"
                "~/.zsh/plugins/zsh-autosuggestions/"
                "~/.zsh/plugins/zsh-syntax-highlighting/"
                "~/.zsh/plugins/zsh-autopair/"
            )
            DET_DISTRO=(
                "Universal: Clones directly from GitHub to ~/.zsh/plugins on any Linux distro"
            )
            ;;
        bash)
            DET_BENEFITS=(
                "Consistent interactive fallback shell across all subshells and SSH sessions"
                "Standardized PATH exports (~/.local/bin, ~/.cargo/bin, ~/go/bin)"
                "Starship prompt initialization fallback for Bash"
                "Non-interactive script safety and POSIX standard compliance"
            )
            DET_ASSETS=(
                "~/.bashrc, ~/.bash_profile, ~/.profile"
            )
            DET_DISTRO=(
                "Universal: Works identically on Arch, Fedora, and Debian"
            )
            ;;
        ghostty)
            DET_BENEFITS=(
                "GPU-accelerated modern terminal with epoll event loop architecture"
                "Quake drop-down terminal toggle on F12 keypress"
                "CSI-u extended keyboard protocol support for Vim/Tmux modifier key combinations"
                "Dynamic terminal window and tab titles synchronized with current directory"
                "Live color theme synchronization matching active Omarchy theme"
            )
            DET_ASSETS=(
                "~/.config/ghostty/config"
            )
            DET_DISTRO=(
                "Arch / Omarchy: Native package ghostty"
                "Fedora: Copr repository or official RPM package"
                "Debian: Official ghostty .deb release package"
            )
            ;;
        terminals)
            DET_BENEFITS=(
                "Pre-configured modern terminals: Kitty, Alacritty, and Foot"
                "GPU acceleration and low-latency input handling on Wayland and X11"
                "Consistent Omarchy dark color palette across all three terminals"
                "JetBrains Mono Nerd Font typography with ligatures and glyphs"
                "CSI-u key protocol support for advanced terminal shortcuts"
            )
            DET_ASSETS=(
                "~/.config/kitty/kitty.conf"
                "~/.config/alacritty/alacritty.toml"
                "~/.config/foot/foot.ini"
            )
            DET_DISTRO=(
                "Universal: Kitty, Alacritty, and Foot are available in Arch, Fedora, and Debian"
            )
            ;;
        tmux)
            DET_BENEFITS=(
                "Terminal multiplexer with custom status line matching active theme"
                "Seamless Vim/Tmux pane navigation using Ctrl-h/j/k/l"
                "Intuitive pane split bindings (| for horizontal, - for vertical)"
                "24-bit truecolor support, mouse scrolling, and automatic window renumbering"
            )
            DET_ASSETS=(
                "~/.tmux.conf"
                "~/.config/tmux/tmux.conf"
            )
            DET_DISTRO=(
                "Universal: Available in Arch (pacman), Fedora (dnf), and Debian (apt)"
            )
            ;;
        nvim)
            DET_BENEFITS=(
                "LazyVim IDE distribution: Ultra-fast startup with lazy plugin loading"
                "Built-in Language Server Protocol (LSP), Treesitter, and Telescope search"
                "Google Antigravity AI Neovim sidebar: In-editor AI agentic coding assistant"
                "Live theme hotreload: Neovim theme automatically matches Omarchy system theme"
                "Neo-tree file explorer, Git signs, and which-key shortcut helpers"
            )
            DET_ASSETS=(
                "~/.config/nvim/ (init.lua, lua/plugins/, lua/config/)"
            )
            DET_DISTRO=(
                "Universal: Requires Neovim 0.10+ (Arch: pacman, Fedora: dnf, Debian: apt/snap/tar)"
            )
            ;;
        helix)
            DET_BENEFITS=(
                "Modern modal editor with Kakoune-style multiple selections editing paradigm"
                "Zero-configuration LSP and Tree-sitter built directly into the binary"
                "Custom Omarchy Aether theme (~/.config/helix/themes/omarchy.toml)"
                "Built-in fuzzy file picker, symbol explorer, and visual diagnostics"
            )
            DET_ASSETS=(
                "~/.config/helix/config.toml"
                "~/.config/helix/themes/omarchy.toml"
            )
            DET_DISTRO=(
                "Universal: Available via pacman (Arch), dnf (Fedora), apt/cargo (Debian)"
            )
            ;;
        git_tools)
            DET_BENEFITS=(
                "Ergonomic Git aliases: git st, git lg, git undo, git amend, and safe rebase"
                "Lazygit terminal UI (~/.config/lazygit/): Side-by-side diffs, visual branching"
                "Mise toolchain manager (~/.config/mise/): Polyglot runtime version manager (Node/Python/Rust)"
                "Delta syntax-highlighted pager integration for clean unified diffs"
            )
            DET_ASSETS=(
                "~/.config/git/config"
                "~/.config/lazygit/config.yml"
                "~/.config/mise/config.toml"
            )
            DET_DISTRO=(
                "Universal: Git in all distros; Lazygit in pacman/copr/github; Mise via mise.jdx.dev"
            )
            ;;
        btop)
            DET_BENEFITS=(
                "High-performance TUI system resource monitor"
                "Visual real-time CPU per-core graphs, memory and swap utilization breakdown"
                "Interactive process manager: Sort by CPU/MEM, send SIGTERM/SIGKILL"
                "Disk I/O read/write monitoring and network interface bandwidth graphs"
                "Custom Omarchy color theme (~/.config/btop/themes/omarchy.theme)"
            )
            DET_ASSETS=(
                "~/.config/btop/btop.conf"
                "~/.config/btop/themes/omarchy.theme"
            )
            DET_DISTRO=(
                "Universal: Available in Arch (pacman), Fedora (dnf), and Debian (apt)"
            )
            ;;
        hyprland)
            DET_BENEFITS=(
                "Dynamic Wayland tiling window manager configuration with fluid animations"
                "Custom workspace navigation, window splitting rules, and touchpad gestures"
                "hyprland-preview-share-picker: Omarchy screen sharing preview UI with thumbnails"
                "Media and brightness hardware control keys with libnotify OSD alerts"
            )
            DET_ASSETS=(
                "~/.config/hypr/hyprland.conf, hypridle.conf, hyprlock.conf"
                "~/.config/hyprland-preview-share-picker/"
            )
            DET_DISTRO=(
                "★ Arch / Omarchy: Native default desktop environment"
                "Fedora: Requires hyprland package from official Fedora repos"
                "Debian: Requires Hyprland backports / source build on Debian 12+"
            )
            ;;
        desktop_media)
            DET_BENEFITS=(
                "WirePlumber Bluetooth auto-connect: Automatically switches to A2DP sink on boot"
                "IMV: Lightweight GPU-accelerated image viewer for Wayland"
                "Tensaku: On-screen Japanese and text OCR tool for quick translations"
                "Voxtype: High-speed local speech-to-text dictation daemon"
            )
            DET_ASSETS=(
                "~/.config/wireplumber/wireplumber.conf.d/bluetooth-a2dp-autoconnect.conf"
                "~/.config/imv/, ~/.config/tensaku/, ~/.config/voxtype/"
            )
            DET_DISTRO=(
                "★ PipeWire/WirePlumber standard on Arch, Fedora, and Debian 12+"
                "Voxtype and Tensaku are Omarchy-tuned dictation tools"
            )
            ;;
        desktop_common)
            DET_BENEFITS=(
                "Chromium and Brave Wayland hardware acceleration flags (video decode/encode)"
                "Fcitx5 multilingual input method configuration (Japanese, Chinese, etc.)"
                "Standardized XDG user directories and default terminal routing"
                "XCompose typographical symbols and MIME file type associations"
            )
            DET_ASSETS=(
                "~/.config/chromium-flags.conf, brave-origin-flags.conf"
                "~/.config/fcitx5/, ~/.config/autostart/, ~/.config/gtk-3.0/, ~/.XCompose"
                "~/.config/mimeapps.list, ~/.config/xdg-terminals.list, ~/.config/user-dirs.dirs"
            )
            DET_DISTRO=(
                "Universal: Fully cross-distro for any modern Wayland/X11 Linux desktop"
            )
            ;;
        omarchy_core)
            DET_BENEFITS=(
                "★ Central Omarchy workspace shell framework and system state management"
                "Aether Dynamic Theme Switcher: omarchy theme set hrc / mm93"
                "Live theme synchronization across Ghostty, Alacritty, Btop, Helix, Neovim, and GTK"
                "Event-driven shell hooks: post-boot.d, post-update.d, theme-set.d, font-set.d"
                "QML desktop widgets and system status monitoring integrations"
            )
            DET_ASSETS=(
                "~/.config/omarchy/ (shell.json, shell.toml, omasettings.json)"
                "~/.config/omarchy/themes/ (hrc, mm93)"
                "~/.config/omarchy/hooks/"
            )
            DET_DISTRO=(
                "★ OMARCHY EXCLUSIVE: Core configuration framework for Omarchy systems"
                "Can be run on Arch, Fedora, and Debian as a portable dotfiles workspace suite"
            )
            ;;
        powerprofiles)
            DET_BENEFITS=(
                "Non-root ACPI platform profile switching: Quiet, Balanced, Performance"
                "Battery longevity protection: Dell WMI and ACPI charge start/stop thresholds (80%)"
                "Prevents battery degradation from sustained AC power plug-in"
                "Udev rules & systemd-tmpfiles granting wheel group access without sudo passwords"
            )
            DET_ASSETS=(
                "~/.local/bin/omarchy-powerprofiles-list, omarchy-powerprofiles-set"
                "/etc/udev/rules.d/99-platform-profile.rules"
                "/etc/udev/rules.d/99-battery-charge-thresholds.rules"
                "/etc/tmpfiles.d/battery-charge-thresholds.conf"
            )
            DET_DISTRO=(
                "★ OMARCHY & LAPTOP HARDWARE EXCLUSIVE: Hardware power management"
                "Supports modern Dell, ThinkPad, ASUS, and ACPI platform_profile laptops"
            )
            ;;
        antigravity)
            DET_BENEFITS=(
                "Google Antigravity AI coding assistant command-line launcher"
                "Agentic pair-programming, multi-file code editing, and subagent orchestration"
                "Shell alias agy for rapid terminal session invocation"
                "Telemetry configuration and automated launcher integrity verification"
            )
            DET_ASSETS=(
                "~/.local/bin/antigravity-cli"
            )
            DET_DISTRO=(
                "Universal: Python / POSIX executable running on Arch, Fedora, and Debian"
            )
            ;;
    esac
}

# Selection states (1 = selected, 0 = unselected)
declare -A SELECTED=()
for k in "${MODULE_KEYS[@]}"; do
    SELECTED["$k"]=1
done

# Preset helper functions
apply_preset() {
    local preset="$1"
    for k in "${MODULE_KEYS[@]}"; do
        SELECTED["$k"]=0
    done

    case "$preset" in
        "all"|"full")
            for k in "${MODULE_KEYS[@]}"; do
                SELECTED["$k"]=1
            done
            ;;
        "cli")
            for k in prereqs zsh zsh_plugins bash ghostty tmux nvim helix git_tools btop antigravity; do
                SELECTED["$k"]=1
            done
            ;;
        "desktop")
            for k in prereqs hyprland desktop_media desktop_common omarchy_core powerprofiles terminals ghostty; do
                SELECTED["$k"]=1
            done
            ;;
        "none")
            # All stay 0
            ;;
    esac
}

# Determine which module owns a given relative dotfile path
MODULE_RESULT="other"
get_module_for_path() {
    case "$1" in
        .zshrc|.config/zsh*|.config/starship.toml)
            MODULE_RESULT="zsh" ;;
        .bashrc|.bash_profile|.profile)
            MODULE_RESULT="bash" ;;
        .tmux.conf|.config/tmux*)
            MODULE_RESULT="tmux" ;;
        .config/ghostty*)
            MODULE_RESULT="ghostty" ;;
        .config/kitty*|.config/alacritty*|.config/foot*)
            MODULE_RESULT="terminals" ;;
        .config/nvim*)
            MODULE_RESULT="nvim" ;;
        .config/helix*)
            MODULE_RESULT="helix" ;;
        .config/git*|.config/lazygit*|.config/mise*)
            MODULE_RESULT="git_tools" ;;
        .config/btop*)
            MODULE_RESULT="btop" ;;
        .config/hypr*|.config/hyprland-preview-share-picker*)
            MODULE_RESULT="hyprland" ;;
        .config/wireplumber*|.config/imv*|.config/tensaku*|.config/voxtype*)
            MODULE_RESULT="desktop_media" ;;
        .config/autostart*|.config/fcitx5*|.config/gtk-3.0*|.config/user-dirs.dirs|.config/mimeapps.list|.config/xdg-terminals.list|.config/chromium-flags.conf|.config/brave-origin-flags.conf|.XCompose)
            MODULE_RESULT="desktop_common" ;;
        .config/omarchy*)
            MODULE_RESULT="omarchy_core" ;;
        .local/bin/omarchy-powerprofiles-*)
            MODULE_RESULT="powerprofiles" ;;
        .local/bin/antigravity-cli)
            MODULE_RESULT="antigravity" ;;
        *)
            MODULE_RESULT="other" ;;
    esac
}

# ------------------------------------------------------------------------------
# Terminal Control & Raw Mode Handlers
# ------------------------------------------------------------------------------
ORIGINAL_STTY=""
REBUILD_NEEDED=1
shopt -s checkwinsize 2>/dev/null || true

handle_winch() {
    COLUMNS=0
    LINES=0
    REBUILD_NEEDED=1
}

update_terminal_size() {
    local l=0 c=0
    if read -r l c < <(stty size 2>/dev/null); then
        LINES="$l"
        COLUMNS="$c"
    else
        COLUMNS="${COLUMNS:-80}"
        LINES="${LINES:-24}"
    fi

    BOX_W=74
    [ "$COLUMNS" -lt 76 ] && BOX_W=$((COLUMNS - 2))
    [ "$BOX_W" -lt 50 ] && BOX_W=50
    INNER_W=$((BOX_W - 2))

    local sp="${SPACES:0:INNER_W}"
    HLINE="${sp// /$B_HORIZ}"
}

setup_terminal() {
    if [ "$IS_TTY" = true ]; then
        ORIGINAL_STTY="$(stty -g 2>/dev/null || true)"
        printf '\033[?25l\033[?1049h\033]0;OmarchIt - The Sanjith Way\007'
        clear
        REBUILD_NEEDED=1
        update_terminal_size
        trap handle_winch WINCH
    fi
}

cleanup_terminal() {
    if [ "$IS_TTY" = true ]; then
        trap - WINCH 2>/dev/null || true
        printf '\033[?1049l\033[?25h'
        if [ -n "$ORIGINAL_STTY" ]; then
            stty "$ORIGINAL_STTY" 2>/dev/null || true
        else
            stty sane 2>/dev/null || true
        fi
    fi
}

pause_raw_mode() {
    if [ "$IS_TTY" = true ]; then
        printf '\033[?25h'
        if [ -n "$ORIGINAL_STTY" ]; then
            stty "$ORIGINAL_STTY" 2>/dev/null || true
        else
            stty sane 2>/dev/null || true
        fi
    fi
}

resume_raw_mode() {
    if [ "$IS_TTY" = true ]; then
        printf '\033[?25l'
        stty -icanon -echo min 1 time 0 2>/dev/null || true
    fi
}

trap cleanup_terminal EXIT INT TERM

# Read a single keypress cleanly with sub-millisecond escape sequence handling
KEY_PRESSED=""
read_key() {
    KEY_PRESSED=""
    local char=""
    if ! IFS= read -rsn1 char 2>/dev/null; then
        KEY_PRESSED="EOF"
        return 1
    fi

    if [[ "$char" == $'\x1b' ]]; then
        local rest=""
        # Fast path: If terminal sent multi-byte sequence, the rest of the bytes
        # are already queued in the OS input buffer right now.
        if read -t 0; then
            local first=""
            IFS= read -rsn1 first 2>/dev/null || true
            rest+="$first"
            if [[ "$first" == "[" ]]; then
                while read -t 0; do
                    local c=""
                    IFS= read -rsn1 c 2>/dev/null || break
                    rest+="$c"
                    [[ "$c" =~ [a-zA-Z~] ]] && break
                done
            elif [[ "$first" == "O" ]]; then
                if read -t 0; then
                    local c=""
                    IFS= read -rsn1 c 2>/dev/null || true
                    rest+="$c"
                fi
            fi
            KEY_PRESSED="$char$rest"
            return 0
        fi

        # If not queued immediately, wait briefly (20ms) to distinguish standalone ESC
        if IFS= read -rsn1 -t 0.02 c 2>/dev/null; then
            rest+="$c"
            if [[ "$c" == "[" ]]; then
                while IFS= read -rsn1 -t 0.02 next_c 2>/dev/null; do
                    rest+="$next_c"
                    [[ "$next_c" =~ [a-zA-Z~] ]] && break
                done
            elif [[ "$c" == "O" ]]; then
                if IFS= read -rsn1 -t 0.02 next_c 2>/dev/null; then
                    rest+="$next_c"
                fi
            fi
            KEY_PRESSED="$char$rest"
        else
            KEY_PRESSED=$'\x1b'
        fi
    else
        KEY_PRESSED="$char"
    fi
}

# ------------------------------------------------------------------------------
# Privilege Escalation Helper
# ------------------------------------------------------------------------------
run_privileged() {
    if [ "$EUID" -eq 0 ]; then
        "$@"
    elif command -v sudo >/dev/null 2>&1; then
        sudo "$@"
    elif command -v doas >/dev/null 2>&1; then
        doas "$@"
    else
        "$@"
    fi
}

# ------------------------------------------------------------------------------
# Prerequisites Installation
# ------------------------------------------------------------------------------
get_prerequisite_packages() {
    case "$PKG_FAMILY" in
        arch)
            echo "zsh fzf bat eza ripgrep zoxide jq fd tldr wl-clipboard libnotify fastfetch btop lazygit neovim tmux git curl"
            ;;
        debian)
            echo "zsh fzf bat ripgrep zoxide jq fd-find libnotify-bin btop tmux git curl wl-clipboard neovim eza fastfetch tldr"
            ;;
        fedora)
            echo "zsh fzf bat eza ripgrep zoxide jq fd-find libnotify btop tmux git curl wl-clipboard neovim fastfetch lazygit tldr"
            ;;
        suse)
            echo "zsh fzf bat eza ripgrep zoxide jq fd libnotify-tools btop tmux git curl wl-clipboard neovim fastfetch"
            ;;
        void)
            echo "zsh fzf bat eza ripgrep zoxide jq fd libnotify btop tmux git curl wl-clipboard neovim fastfetch lazygit"
            ;;
        alpine)
            echo "zsh fzf bat eza ripgrep zoxide jq fd libnotify btop tmux git curl neovim bash util-linux shadow"
            ;;
        darwin)
            echo "zsh fzf bat eza ripgrep zoxide jq fd btop lazygit neovim tmux git curl"
            ;;
        *)
            echo "zsh fzf bat ripgrep zoxide jq fd git curl tmux neovim"
            ;;
    esac
}

install_system_prerequisites() {
    local log_fn="$1"
    local raw_pkgs
    raw_pkgs="$(get_prerequisite_packages)"
    read -r -a pkgs <<< "$raw_pkgs"

    "$log_fn" "Detecting system package status for $DISTRO_NAME ($PKG_MGR)..."

    if [ "$DRY_RUN" = true ]; then
        "$log_fn" "[DRY-RUN] Would install packages via $PKG_MGR: ${pkgs[*]}"
        return 0
    fi

    # Check for missing packages (fast path checks binary and aliases first)
    local missing=()
    for p in "${pkgs[@]}"; do
        if command -v "$p" >/dev/null 2>&1; then
            continue
        fi
        case "$p" in
            fd-find) (command -v fd >/dev/null 2>&1 || command -v fdfind >/dev/null 2>&1) && continue ;;
            bat) command -v batcat >/dev/null 2>&1 && continue ;;
            libnotify-bin|libnotify|libnotify-tools) command -v notify-send >/dev/null 2>&1 && continue ;;
            tldr) command -v tealdeer >/dev/null 2>&1 && continue ;;
        esac
        case "$PKG_FAMILY" in
            arch)
                if ! pacman -Q "$p" >/dev/null 2>&1; then
                    missing+=("$p")
                fi
                ;;
            debian)
                if ! dpkg -s "$p" >/dev/null 2>&1; then
                    missing+=("$p")
                fi
                ;;
            fedora)
                if ! rpm -q "$p" >/dev/null 2>&1; then
                    missing+=("$p")
                fi
                ;;
            *)
                missing+=("$p")
                ;;
        esac
    done

    if [ "${#missing[@]}" -eq 0 ]; then
        "$log_fn" "All required prerequisite packages are already installed."
        return 0
    fi

    "$log_fn" "Installing ${#missing[@]} missing packages: ${missing[*]}"

    # Request sudo access with normal terminal input if needed
    if [ "$EUID" -ne 0 ] && command -v sudo >/dev/null 2>&1; then
        pause_raw_mode
        echo -e "\n${C_YELLOW}Authentication required to install prerequisites via $PKG_MGR...${RESET}"
        sudo -v || true
        resume_raw_mode
    fi

    case "$PKG_FAMILY" in
        arch)
            run_privileged pacman -S --needed --noconfirm "${missing[@]}" || {
                "$log_fn" "${C_YELLOW}Batch install failed, attempting package-by-package...${RESET}"
                for p in "${missing[@]}"; do
                    run_privileged pacman -S --needed --noconfirm "$p" 2>/dev/null || "$log_fn" "Skipped optional $p"
                done
            }
            ;;
        debian)
            run_privileged apt-get update -y
            run_privileged apt-get install -y "${missing[@]}" || {
                for p in "${missing[@]}"; do
                    run_privileged apt-get install -y "$p" 2>/dev/null || "$log_fn" "Skipped optional $p"
                done
            }
            # Debian/Ubuntu symlink compatibility for batcat and fdfind
            mkdir -p "$TARGET_DIR/.local/bin"
            if command -v batcat >/dev/null 2>&1 && [ ! -e "$TARGET_DIR/.local/bin/bat" ]; then
                ln -sf "$(command -v batcat)" "$TARGET_DIR/.local/bin/bat"
                "$log_fn" "Symlinked batcat -> ~/.local/bin/bat"
            fi
            if command -v fdfind >/dev/null 2>&1 && [ ! -e "$TARGET_DIR/.local/bin/fd" ]; then
                ln -sf "$(command -v fdfind)" "$TARGET_DIR/.local/bin/fd"
                "$log_fn" "Symlinked fdfind -> ~/.local/bin/fd"
            fi
            ;;
        fedora)
            run_privileged dnf install -y "${missing[@]}" || {
                for p in "${missing[@]}"; do
                    run_privileged dnf install -y "$p" 2>/dev/null || "$log_fn" "Skipped optional $p"
                done
            }
            mkdir -p "$TARGET_DIR/.local/bin"
            if command -v fdfind >/dev/null 2>&1 && [ ! -e "$TARGET_DIR/.local/bin/fd" ]; then
                ln -sf "$(command -v fdfind)" "$TARGET_DIR/.local/bin/fd"
                "$log_fn" "Symlinked fdfind -> ~/.local/bin/fd"
            fi
            ;;
        suse)
            run_privileged zypper --non-interactive install "${missing[@]}" || true
            ;;
        void)
            run_privileged xbps-install -Sy "${missing[@]}" || true
            ;;
        alpine)
            run_privileged apk add "${missing[@]}" || true
            ;;
        darwin)
            brew install "${missing[@]}" || true
            ;;
        *)
            "$log_fn" "${C_YELLOW}Unknown package manager. Please install manually: ${missing[*]}${RESET}"
            ;;
    esac

    "$log_fn" "Prerequisites installation finished."
}

# ------------------------------------------------------------------------------
# File Deployment
# ------------------------------------------------------------------------------
DEPLOYED_COUNT=0
BACKUP_COUNT=0
BACKUP_FILES=()
declare -A CREATED_DIRS=()

deploy_single_item() {
    local src="$1"
    local rel_path="${src#$DOTFILES_DIR/}"
    local dest="$TARGET_DIR/$rel_path"
    local dest_dir="${dest%/*}"
    local log_fn="$2"

    if [ "$DRY_RUN" = true ]; then
        "$log_fn" "[DRY-RUN] Deploy $rel_path -> $dest ($MODE)"
        DEPLOYED_COUNT=$((DEPLOYED_COUNT + 1))
        return 0
    fi

    if [ -z "${CREATED_DIRS["$dest_dir"]:-}" ]; then
        [ ! -d "$dest_dir" ] && mkdir -p "$dest_dir"
        CREATED_DIRS["$dest_dir"]=1
    fi

    # Backup logic if file differs
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        if [ "$MODE" = "link" ] && [ "$(readlink -f "$dest" 2>/dev/null)" = "$(readlink -f "$src" 2>/dev/null)" ]; then
            "$log_fn" "Already linked: $rel_path"
            DEPLOYED_COUNT=$((DEPLOYED_COUNT + 1))
            return 0
        fi

        # Backup if content differs
        if ! cmp -s "$src" "$dest" 2>/dev/null; then
            local ts
            printf -v ts "%(%Y%m%d%H%M%S)T" -1 2>/dev/null || ts="$(date +%Y%m%d%H%M%S)"
            local backup_path="${dest}.backup.${ts}"
            mv "$dest" "$backup_path"
            BACKUP_COUNT=$((BACKUP_COUNT + 1))
            BACKUP_FILES+=("$backup_path")
            "$log_fn" "${C_YELLOW}Backed up existing:${RESET} $dest -> $backup_path"
        else
            rm -rf "$dest"
        fi
    fi

    if [ "$MODE" = "link" ]; then
        ln -snf "$src" "$dest"
        "$log_fn" "${C_GREEN}Linked:${RESET} $rel_path"
    else
        cp -a "$src" "$dest"
        "$log_fn" "${C_GREEN}Copied:${RESET} $rel_path"
    fi
    DEPLOYED_COUNT=$((DEPLOYED_COUNT + 1))
}

# ------------------------------------------------------------------------------
# Zsh Plugins Installation
# ------------------------------------------------------------------------------
PLUGINS_CLONED=0

install_zsh_plugins() {
    local log_fn="$1"
    local target_plugin_dir="$TARGET_DIR/.zsh/plugins"

    "$log_fn" "Checking external Zsh plugins in $target_plugin_dir..."

    if [ "$DRY_RUN" = true ]; then
        "$log_fn" "[DRY-RUN] Would clone external plugins to $target_plugin_dir"
        return 0
    fi

    mkdir -p "$target_plugin_dir"

    declare -A ZSH_PLUGINS=(
        ["fzf-tab"]="https://github.com/Aloxaf/fzf-tab"
        ["zsh-autopair"]="https://github.com/hlissner/zsh-autopair"
        ["zsh-autosuggestions"]="https://github.com/zsh-users/zsh-autosuggestions"
        ["zsh-syntax-highlighting"]="https://github.com/zsh-users/zsh-syntax-highlighting"
    )

    for plugin in "${!ZSH_PLUGINS[@]}"; do
        local pdir="$target_plugin_dir/$plugin"
        if [ ! -d "$pdir" ]; then
            "$log_fn" "Cloning $plugin from ${ZSH_PLUGINS[$plugin]}..."
            if git clone --depth=1 "${ZSH_PLUGINS[$plugin]}" "$pdir" >/dev/null 2>&1; then
                "$log_fn" "${C_GREEN}Cloned:${RESET} $plugin"
                PLUGINS_CLONED=$((PLUGINS_CLONED + 1))
            else
                "$log_fn" "${C_RED}Failed to clone:${RESET} $plugin"
            fi
        else
            "$log_fn" "Plugin $plugin already exists."
        fi
    done
}

# ------------------------------------------------------------------------------
# Hardware & Permissions Setup
# ------------------------------------------------------------------------------
configure_hardware_rules() {
    local log_fn="$1"

    "$log_fn" "Ensuring executable permissions on helper scripts..."
    if [ "$DRY_RUN" = true ]; then
        "$log_fn" "[DRY-RUN] Would set executable permissions and install ACPI udev rule and CPU EPP udev rule"
        return 0
    fi

    chmod +x "$TARGET_DIR/.local/bin/omarchy-powerprofiles-"* 2>/dev/null || true
    chmod +x "$TARGET_DIR/.config/omarchy/plugins/sanjith.power/"*.sh 2>/dev/null || true
    # New binaries: hyprd IPC event daemon + CPU EPP setter
    chmod +x "$TARGET_DIR/.local/bin/hyprd" 2>/dev/null || true
    chmod +x "$TARGET_DIR/.local/bin/omarchy-set-epp" 2>/dev/null || true

    # Udev rule for ACPI platform_profile
    "$log_fn" "Checking /etc/udev/rules.d/99-platform-profile.rules..."
    local udev_content
    udev_content='# Grant wheel group write access to ACPI platform_profile
SUBSYSTEM=="platform", ACTION=="add|change", TEST=="/sys/firmware/acpi/platform_profile", RUN+="/usr/bin/chmod 0664 /sys/firmware/acpi/platform_profile", RUN+="/usr/bin/chgrp wheel /sys/firmware/acpi/platform_profile"
SUBSYSTEM=="power_supply", ACTION=="add|change", TEST=="/sys/firmware/acpi/platform_profile", RUN+="/usr/bin/chmod 0664 /sys/firmware/acpi/platform_profile", RUN+="/usr/bin/chgrp wheel /sys/firmware/acpi/platform_profile"
SUBSYSTEM=="acpi", ACTION=="add|change", TEST=="/sys/firmware/acpi/platform_profile", RUN+="/usr/bin/chmod 0664 /sys/firmware/acpi/platform_profile", RUN+="/usr/bin/chgrp wheel /sys/firmware/acpi/platform_profile"
'
    # Udev rule for battery charge thresholds (standard sysfs & Dell WMI sysman)
    local batt_udev_content
    batt_udev_content='# Grant wheel group write access to battery charge control attributes
SUBSYSTEM=="power_supply", KERNEL=="BAT*", ACTION=="add|change", RUN+="/usr/bin/chmod 0664 /sys/class/power_supply/%k/charge_control_start_threshold /sys/class/power_supply/%k/charge_control_end_threshold /sys/class/power_supply/%k/charge_types", RUN+="/usr/bin/chgrp wheel /sys/class/power_supply/%k/charge_control_start_threshold /sys/class/power_supply/%k/charge_control_end_threshold /sys/class/power_supply/%k/charge_types"
SUBSYSTEM=="firmware-attributes", ACTION=="add|change", TEST=="/sys/class/firmware-attributes/dell-wmi-sysman/attributes/CustomChargeStop/current_value", RUN+="/usr/bin/chmod 0664 /sys/class/firmware-attributes/dell-wmi-sysman/attributes/CustomChargeStart/current_value /sys/class/firmware-attributes/dell-wmi-sysman/attributes/CustomChargeStop/current_value /sys/class/firmware-attributes/dell-wmi-sysman/attributes/PrimaryBattChargeCfg/current_value", RUN+="/usr/bin/chgrp wheel /sys/class/firmware-attributes/dell-wmi-sysman/attributes/CustomChargeStart/current_value /sys/class/firmware-attributes/dell-wmi-sysman/attributes/CustomChargeStop/current_value /sys/class/firmware-attributes/dell-wmi-sysman/attributes/PrimaryBattChargeCfg/current_value"
SUBSYSTEM=="platform", ACTION=="add|change", TEST=="/sys/class/firmware-attributes/dell-wmi-sysman/attributes/CustomChargeStop/current_value", RUN+="/usr/bin/chmod 0664 /sys/class/firmware-attributes/dell-wmi-sysman/attributes/CustomChargeStart/current_value /sys/class/firmware-attributes/dell-wmi-sysman/attributes/CustomChargeStop/current_value /sys/class/firmware-attributes/dell-wmi-sysman/attributes/PrimaryBattChargeCfg/current_value", RUN+="/usr/bin/chgrp wheel /sys/class/firmware-attributes/dell-wmi-sysman/attributes/CustomChargeStart/current_value /sys/class/firmware-attributes/dell-wmi-sysman/attributes/CustomChargeStop/current_value /sys/class/firmware-attributes/dell-wmi-sysman/attributes/PrimaryBattChargeCfg/current_value"
SUBSYSTEM=="wmi", ACTION=="add|change", TEST=="/sys/class/firmware-attributes/dell-wmi-sysman/attributes/CustomChargeStop/current_value", RUN+="/usr/bin/chmod 0664 /sys/class/firmware-attributes/dell-wmi-sysman/attributes/CustomChargeStart/current_value /sys/class/firmware-attributes/dell-wmi-sysman/attributes/CustomChargeStop/current_value /sys/class/firmware-attributes/dell-wmi-sysman/attributes/PrimaryBattChargeCfg/current_value", RUN+="/usr/bin/chgrp wheel /sys/class/firmware-attributes/dell-wmi-sysman/attributes/CustomChargeStart/current_value /sys/class/firmware-attributes/dell-wmi-sysman/attributes/CustomChargeStop/current_value /sys/class/firmware-attributes/dell-wmi-sysman/attributes/PrimaryBattChargeCfg/current_value"
'
    local batt_tmpfiles_content
    batt_tmpfiles_content='# Grant wheel group write access to battery charge control attributes
z /sys/class/power_supply/BAT*/charge_control_start_threshold 0664 root wheel - -
z /sys/class/power_supply/BAT*/charge_control_end_threshold 0664 root wheel - -
z /sys/class/power_supply/BAT*/charge_types 0664 root wheel - -
z /sys/class/firmware-attributes/dell-wmi-sysman/attributes/CustomChargeStart/current_value 0664 root wheel - -
z /sys/class/firmware-attributes/dell-wmi-sysman/attributes/CustomChargeStop/current_value 0664 root wheel - -
z /sys/class/firmware-attributes/dell-wmi-sysman/attributes/PrimaryBattChargeCfg/current_value 0664 root wheel - -
'

    if [ -w /etc/udev/rules.d ]; then
        printf "%s" "$udev_content" > /etc/udev/rules.d/99-platform-profile.rules
        printf "%s" "$batt_udev_content" > /etc/udev/rules.d/99-battery-charge-thresholds.rules
        [ -d /etc/tmpfiles.d ] && [ -w /etc/tmpfiles.d ] && printf "%s" "$batt_tmpfiles_content" > /etc/tmpfiles.d/battery-charge-thresholds.conf
        udevadm control --reload 2>/dev/null || true
        command -v systemd-tmpfiles >/dev/null 2>&1 && systemd-tmpfiles --create /etc/tmpfiles.d/battery-charge-thresholds.conf 2>/dev/null || true
        "$log_fn" "${C_GREEN}Installed:${RESET} Hardware power profile and battery charge threshold rules"
    elif command -v run0 >/dev/null 2>&1; then
        run0 bash -c "
            printf '%s' \"$udev_content\" > /etc/udev/rules.d/99-platform-profile.rules
            printf '%s' \"$batt_udev_content\" > /etc/udev/rules.d/99-battery-charge-thresholds.rules
            mkdir -p /etc/tmpfiles.d && printf '%s' \"$batt_tmpfiles_content\" > /etc/tmpfiles.d/battery-charge-thresholds.conf
            udevadm control --reload 2>/dev/null || true
            command -v systemd-tmpfiles >/dev/null 2>&1 && systemd-tmpfiles --create /etc/tmpfiles.d/battery-charge-thresholds.conf 2>/dev/null || true
        " 2>/dev/null || true
        "$log_fn" "${C_GREEN}Installed via run0:${RESET} Hardware power profile and battery charge threshold rules"
    elif command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
        echo "$udev_content" | sudo tee /etc/udev/rules.d/99-platform-profile.rules >/dev/null 2>&1 || true
        echo "$batt_udev_content" | sudo tee /etc/udev/rules.d/99-battery-charge-thresholds.rules >/dev/null 2>&1 || true
        echo "$batt_tmpfiles_content" | sudo tee /etc/tmpfiles.d/battery-charge-thresholds.conf >/dev/null 2>&1 || true
        sudo udevadm control --reload 2>/dev/null || true
        sudo systemd-tmpfiles --create /etc/tmpfiles.d/battery-charge-thresholds.conf 2>/dev/null || true
        "$log_fn" "${C_GREEN}Installed via sudo:${RESET} Hardware power profile and battery charge threshold rules"
    else
        "$log_fn" "${C_YELLOW}Note: Root privileges required for udev rule; skipped hardware power profile and battery threshold udev config.${RESET}"
    fi

    # ── CPU EPP Auto-Switching Udev Rule ────────────────────────────────────
    # Adjusts Energy Performance Preference on AC plug/unplug events.
    local epp_src="$DOTFILES_DIR/.config/udev/rules.d/99-cpu-epp-ac.rules"
    local epp_dst="/etc/udev/rules.d/99-cpu-epp-ac.rules"
    if [ -f "$epp_src" ]; then
        "$log_fn" "Checking $epp_dst..."
        local epp_installed=false
        if [ -w /etc/udev/rules.d ]; then
            cp "$epp_src" "$epp_dst" 2>/dev/null && epp_installed=true
        elif command -v run0 >/dev/null 2>&1; then
            run0 cp "$epp_src" "$epp_dst" 2>/dev/null && epp_installed=true
        elif command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
            sudo cp "$epp_src" "$epp_dst" 2>/dev/null && epp_installed=true
        fi
        if [ "$epp_installed" = true ]; then
            # Reload udev rules (already triggered above but safe to repeat)
            { udevadm control --reload 2>/dev/null || \
              run0 udevadm control --reload 2>/dev/null || \
              sudo udevadm control --reload 2>/dev/null; } || true
            "$log_fn" "${C_GREEN}Installed:${RESET} CPU EPP AC auto-switching udev rule"
        else
            "$log_fn" "${C_YELLOW}Note: Skipped CPU EPP udev rule (no write access to /etc/udev/rules.d).${RESET}"
        fi
    fi

    # Enable hyprd systemd user service if systemctl --user is available
    if command -v systemctl >/dev/null 2>&1 && systemctl --user status >/dev/null 2>&1; then
        systemctl --user enable hyprd.service 2>/dev/null || true
        "$log_fn" "${C_GREEN}Enabled:${RESET} hyprd Hyprland IPC daemon (systemctl --user)"
    fi
}

# ------------------------------------------------------------------------------
# TUI Rendering & Screens
# ------------------------------------------------------------------------------

# Helper to pad text to an exact column width (pure bash, zero subshells)
PAD_RESULT=""
pad_string() {
    local text="$1"
    local width="$2"
    local len="${#text}"
    if [[ "$text" == *$'\x1b'* ]]; then
        local raw="$text"
        while [[ "$raw" =~ $ANSI_RE ]]; do
            raw="${raw//${BASH_REMATCH[0]}/}"
        done
        len="${#raw}"
    fi
    local pad=$((width - len))
    if [ "$pad" -gt 0 ]; then
        PAD_RESULT="${text}${SPACES:0:pad}"
    else
        PAD_RESULT="$text"
    fi
}

# Box Border Characters
B_TOP_L="╭"
B_TOP_R="╮"
B_BOT_L="╰"
B_BOT_R="╯"
B_HORIZ="─"
B_VERT="│"
B_DIV_L="├"
B_DIV_R="┤"

# Distribution ASCII Art
DISTRO_ART_COLOR=""
declare -a DISTRO_ART=()

get_distro_art() {
    case "$DISTRO_ID" in
        arch|omarchy|manjaro|endeavouros|garuda|artix|cachyos|arcolinux)
            DISTRO_ART_COLOR="${C_PRIMARY}"
            DISTRO_ART=(
                "      /\\        "
                "     /  \\       "
                "    /\\   \\      "
                "   /      \\     "
                "  /   ,,   \\    "
                " /   |  |  -\\   "
            )
            ;;
        fedora|rhel|centos|almalinux|rocky|nobara)
            DISTRO_ART_COLOR="${C_PRIMARY}"
            DISTRO_ART=(
                "      ,'''''.   "
                "     |   ,.  |  "
                "     |  |  '_'  "
                ",....|  |..     "
                ".'  ,_;|   ..'  "
                "|  |   |  |     "
            )
            ;;
        debian|kali|raspbian)
            DISTRO_ART_COLOR="${C_RED}"
            DISTRO_ART=(
                "    _____       "
                "   /  __ \\      "
                "  |  /    |     "
                "  |  \\___-      "
                "  -_            "
                "    --_         "
            )
            ;;
        ubuntu|pop|linuxmint|elementary|neon)
            DISTRO_ART_COLOR="${C_YELLOW}"
            DISTRO_ART=(
                "    ..;,; .,;,. "
                " .,lool: .ooooo,"
                ";oo;:    .coool."
                "  :oooo,  'oo.  "
                "  looooc  :oo'  "
                "   '::'   ,oo:  "
            )
            ;;
        *)
            case "$PKG_FAMILY" in
                arch)
                    DISTRO_ART_COLOR="${C_PRIMARY}"
                    DISTRO_ART=(
                        "      /\\        "
                        "     /  \\       "
                        "    /\\   \\      "
                        "   /      \\     "
                        "  /   ,,   \\    "
                        " /   |  |  -\\   "
                    )
                    ;;
                fedora)
                    DISTRO_ART_COLOR="${C_PRIMARY}"
                    DISTRO_ART=(
                        "      ,'''''.   "
                        "     |   ,.  |  "
                        "     |  |  '_'  "
                        ",....|  |..     "
                        ".'  ,_;|   ..'  "
                        "|  |   |  |     "
                    )
                    ;;
                debian)
                    DISTRO_ART_COLOR="${C_RED}"
                    DISTRO_ART=(
                        "    _____       "
                        "   /  __ \\      "
                        "  |  /    |     "
                        "  |  \\___-      "
                        "  -_            "
                        "    --_         "
                    )
                    ;;
                *)
                    DISTRO_ART_COLOR="${C_YELLOW}"
                    DISTRO_ART=(
                        "    .--.        "
                        "   |o_o |       "
                        "   |:_/ |       "
                        "  //   \\ \\      "
                        " (|     | )     "
                        "/'\\_   _/\`\\     "
                    )
                    ;;
            esac
            ;;
    esac
}

# Selection Menu Screen
run_selection_tui() {
    local cursor_idx=0
    local scroll_offset=0
    local num_keys="${#MODULE_KEYS[@]}"
    local pending_key=""
    local has_pending=0
    local in_detail_view=0

    setup_terminal
    resume_raw_mode

    # Pre-render the banner header into a variable so it is not rebuilt every frame
    local banner=""
    banner+="  ${C_PRIMARY}${BOLD}  ██████╗ ███╗   ███╗ █████╗ ██████╗  ██████╗██╗  ██╗██╗████████╗${RESET}${NL}"
    banner+="  ${C_PRIMARY}${BOLD} ██╔═══██╗████╗ ████║██╔══██╗██╔══██╗██╔════╝██║  ██║██║╚══██╔══╝${RESET}${NL}"
    banner+="  ${C_ACCENT}${BOLD} ██║   ██║██╔████╔██║███████║██████╔╝██║     ███████║██║   ██║   ${RESET}${NL}"
    banner+="  ${C_ACCENT}${BOLD} ╚██████╔╝██║ ╚═╝ ██║██║  ██║██╔══██╗╚██████╗██║  ██║██║   ██║   ${RESET}${NL}"
    banner+="  ${C_WHITE}${BOLD}  ╚═════╝ ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚═╝   ╚═╝   ${RESET}${NL}"
    banner+="  ${C_GRAY}${ITALIC}            ── OmarchIt - The Sanjith Way ──            ${RESET}${NL}${NL}"

    local -a ROW_SEL_ACTIVE=()
    local -a ROW_SEL_INACTIVE=()
    local -a ROW_UNSEL_ACTIVE=()
    local -a ROW_UNSEL_INACTIVE=()
    local -a DESC_ROWS=()
    local -a DETAIL_CARD_TOP=()
    local -a DETAIL_CARD_BODY=()
    local HEADER_BUF=""
    local DIVIDER_ROW=""
    local BOTTOM_ROW=""
    local FOOTER_ROW=""
    local DETAIL_CARD_BOT=""

    rebuild_selection_caches() {
        update_terminal_size
        get_distro_art

        local mode_badge="Symlink"
        [ "$MODE" = "copy" ] && mode_badge="Copy"
        [ "$DRY_RUN" = true ] && mode_badge+=" (Dry-Run)"

        local suite_note="Arch / Omarchy Native Workspace Suite"
        if [ "$PKG_FAMILY" = "fedora" ]; then
            suite_note="Fedora / Red Hat Multi-Distro Suite"
        elif [ "$PKG_FAMILY" = "debian" ]; then
            suite_note="Debian / Ubuntu Multi-Distro Suite"
        fi

        # Right side info lines matching the 6 art lines
        local right_w=$((INNER_W - 19))
        [ "$right_w" -lt 10 ] && right_w=10

        local info_lines=(
            "Distribution : ${DISTRO_NAME}"
            "Package Mgr  : ${PKG_MGR} (${PKG_FAMILY})"
            "Deploy Mode  : ${mode_badge}"
            "Target User  : ${TARGET_DIR}"
            "Suite Note   : ${suite_note}"
            "Controls     : [j/k] Move  [l/→] Details  [Space] Toggle"
        )

        HEADER_BUF=""
        HEADER_BUF+="$banner"

        if [ "$LINES" -ge 28 ]; then
            # Full Distro Art + Info Box
            HEADER_BUF+="  ${C_DARK_GRAY}${B_TOP_L}${HLINE}${B_TOP_R}${RESET}${NL}"
            for ((r=0; r<6; r++)); do
                local art_l="${DISTRO_ART[r]}"
                local info_l="${info_lines[r]}"
                local pad_info=$((right_w - ${#info_l}))
                [ "$pad_info" -lt 0 ] && pad_info=0
                local padded_info="${info_l:0:right_w}${SPACES:0:pad_info}"
                HEADER_BUF+="  ${C_DARK_GRAY}${B_VERT}${RESET} ${DISTRO_ART_COLOR}${art_l}${RESET} ${C_DARK_GRAY}│${RESET} ${C_WHITE}${padded_info}${RESET}${C_DARK_GRAY}${B_VERT}${RESET}${NL}"
            done
            HEADER_BUF+="  ${C_DARK_GRAY}${B_DIV_L}${HLINE}${B_DIV_R}${RESET}${NL}"
        else
            # Compact header for small terminals
            HEADER_BUF+="  ${C_ACCENT}OS:${RESET} ${DISTRO_NAME}  ${C_ACCENT}Pkg:${RESET} ${PKG_MGR}  ${C_ACCENT}Mode:${RESET} ${mode_badge}  ${C_ACCENT}Target:${RESET} ${TARGET_DIR}${NL}${NL}"
            HEADER_BUF+="  ${C_DARK_GRAY}${B_TOP_L}${HLINE}${B_TOP_R}${RESET}${NL}"
        fi

        # Preset Quick Bar inside box
        local preset_pad=$((INNER_W - 57))
        [ "$preset_pad" -lt 0 ] && preset_pad=0
        HEADER_BUF+="  ${C_DARK_GRAY}${B_VERT}${RESET}  Presets: ${C_PRIMARY}[1]${RESET} Full  ${C_PRIMARY}[2]${RESET} CLI  ${C_PRIMARY}[3]${RESET} Desktop  ${C_PRIMARY}[a]${RESET} All  ${C_PRIMARY}[n]${RESET} None${SPACES:0:preset_pad}${C_DARK_GRAY}${B_VERT}${RESET}${NL}"
        HEADER_BUF+="  ${C_DARK_GRAY}${B_DIV_L}${HLINE}${B_DIV_R}${RESET}${NL}"

        DIVIDER_ROW="  ${C_DARK_GRAY}${B_DIV_L}${HLINE}${B_DIV_R}${RESET}${NL}"
        BOTTOM_ROW="  ${C_DARK_GRAY}${B_BOT_L}${HLINE}${B_BOT_R}${RESET}${NL}"
        FOOTER_ROW="  ${C_PRIMARY}[j/k]${RESET} Move  ${C_PRIMARY}[l/→]${RESET} Details  ${C_PRIMARY}[Space]${RESET} Toggle  ${C_PRIMARY}[m]${RESET} Mode  ${C_PRIMARY}[d]${RESET} Dry-Run  ${C_GREEN}[Enter]${RESET} Proceed  ${C_RED}[q]${RESET} Quit${CLR_EOL}${NL}"
        DETAIL_CARD_BOT="  ${C_PRIMARY}[Space]${RESET} Toggle  ${C_PRIMARY}[j/↓]${RESET} Next  ${C_PRIMARY}[k/↑]${RESET} Prev  ${C_PRIMARY}[h/←/q/Esc]${RESET} Back to List  ${C_GREEN}[Enter]${RESET} Back${CLR_EOL}${NL}"

        for ((i = 0; i < num_keys; i++)); do
            local key="${MODULE_KEYS[i]}"
            local name="${MODULE_NAMES[$key]}"
            local tag="${MODULE_TAGS[$key]}"
            local ilen=$(( ${#name} + ${#tag} + 10 ))
            local pad=$((INNER_W - ilen))
            [ "$pad" -lt 0 ] && pad=0

            ROW_SEL_ACTIVE[i]="  ${C_DARK_GRAY}${B_VERT}${C_BG_HIGHLIGHT}${C_PRIMARY}❯ ${C_GREEN}[✔]${RESET}${C_BG_HIGHLIGHT} ${BOLD}${C_WHITE}${name}${RESET}${C_BG_HIGHLIGHT}  ${C_GRAY}[${tag}]${RESET}${C_BG_HIGHLIGHT}${SPACES:0:pad}${RESET}${C_DARK_GRAY}${B_VERT}${RESET}${NL}"
            ROW_SEL_INACTIVE[i]="  ${C_DARK_GRAY}${B_VERT}  ${C_GREEN}[✔]${RESET} ${C_WHITE}${name}${RESET}  ${C_GRAY}[${tag}]${RESET}${SPACES:0:pad}${C_DARK_GRAY}${B_VERT}${RESET}${NL}"
            ROW_UNSEL_ACTIVE[i]="  ${C_DARK_GRAY}${B_VERT}${C_BG_HIGHLIGHT}${C_PRIMARY}❯ ${C_GRAY}[ ]${RESET}${C_BG_HIGHLIGHT} ${BOLD}${C_WHITE}${name}${RESET}${C_BG_HIGHLIGHT}  ${C_GRAY}[${tag}]${RESET}${C_BG_HIGHLIGHT}${SPACES:0:pad}${RESET}${C_DARK_GRAY}${B_VERT}${RESET}${NL}"
            ROW_UNSEL_INACTIVE[i]="  ${C_DARK_GRAY}${B_VERT}  ${C_GRAY}[ ]${RESET} ${C_WHITE}${name}${RESET}  ${C_GRAY}[${tag}]${RESET}${SPACES:0:pad}${C_DARK_GRAY}${B_VERT}${RESET}${NL}"

            local cur_desc="${MODULE_DESCS[$key]}"
            local dlen=$(( 8 + ${#cur_desc} ))
            local dpad=$((INNER_W - dlen))
            [ "$dpad" -lt 0 ] && dpad=0
            DESC_ROWS[i]="  ${C_DARK_GRAY}${B_VERT}${RESET}  ${C_ACCENT}Info:${RESET} ${cur_desc}${SPACES:0:dpad}${C_DARK_GRAY}${B_VERT}${RESET}${NL}"

            # Precalculate Detail Card for this module
            get_module_info "$key"
            local excl_label="${MODULE_EXCLUSIVITIES[$key]}"

            local title_left="  FEATURE DETAILS: ${BOLD}${C_WHITE}${name}${RESET}  ${C_GRAY}[${tag}]${RESET}"
            local title_vis_len=$(( ${#name} + ${#tag} + 22 ))
            local pad_badge=$((INNER_W - title_vis_len - 25))
            [ "$pad_badge" -lt 0 ] && pad_badge=0
            DETAIL_CARD_TOP[i]="  ${C_DARK_GRAY}${B_TOP_L}${HLINE}${B_TOP_R}${RESET}${NL}  ${C_DARK_GRAY}${B_VERT}${RESET}${title_left}${SPACES:0:pad_badge}"

            local body=""
            body+="  ${C_DARK_GRAY}${B_DIV_L}${HLINE}${B_DIV_R}${RESET}${NL}"
            local excl_line="  ${C_ACCENT}Exclusivity${RESET} : ${BOLD}${excl_label}${RESET}"
            local pad_ex=$((INNER_W - ${#excl_label} - 16))
            [ "$pad_ex" -lt 0 ] && pad_ex=0
            body+="  ${C_DARK_GRAY}${B_VERT}${RESET}${excl_line}${SPACES:0:pad_ex}${C_DARK_GRAY}${B_VERT}${RESET}${NL}"
            body+="  ${C_DARK_GRAY}${B_DIV_L}${HLINE}${B_DIV_R}${RESET}${NL}"

            local pad_h1=$((INNER_W - 41))
            [ "$pad_h1" -lt 0 ] && pad_h1=0
            body+="  ${C_DARK_GRAY}${B_VERT}${RESET}  ${C_PRIMARY}${BOLD}WHAT INSTALLING THIS FEATURE GIVES YOU:${RESET}${SPACES:0:pad_h1}${C_DARK_GRAY}${B_VERT}${RESET}${NL}"
            for b in "${DET_BENEFITS[@]}"; do
                local pad_b=$((INNER_W - ${#b} - 5))
                [ "$pad_b" -lt 0 ] && pad_b=0
                body+="  ${C_DARK_GRAY}${B_VERT}${RESET}   • ${C_WHITE}${b:0:$((INNER_W - 5))}${RESET}${SPACES:0:pad_b}${C_DARK_GRAY}${B_VERT}${RESET}${NL}"
            done

            body+="  ${C_DARK_GRAY}${B_VERT}${RESET}${SPACES:0:INNER_W}${C_DARK_GRAY}${B_VERT}${RESET}${NL}"
            local pad_h2=$((INNER_W - 35))
            [ "$pad_h2" -lt 0 ] && pad_h2=0
            body+="  ${C_DARK_GRAY}${B_VERT}${RESET}  ${C_PRIMARY}${BOLD}DEPLOYED CONFIGURATIONS & ASSETS:${RESET}${SPACES:0:pad_h2}${C_DARK_GRAY}${B_VERT}${RESET}${NL}"
            for a in "${DET_ASSETS[@]}"; do
                local pad_a=$((INNER_W - ${#a} - 5))
                [ "$pad_a" -lt 0 ] && pad_a=0
                body+="  ${C_DARK_GRAY}${B_VERT}${RESET}   • ${C_GRAY}${a:0:$((INNER_W - 5))}${RESET}${SPACES:0:pad_a}${C_DARK_GRAY}${B_VERT}${RESET}${NL}"
            done

            body+="  ${C_DARK_GRAY}${B_VERT}${RESET}${SPACES:0:INNER_W}${C_DARK_GRAY}${B_VERT}${RESET}${NL}"
            local pad_h3=$((INNER_W - 49))
            [ "$pad_h3" -lt 0 ] && pad_h3=0
            body+="  ${C_DARK_GRAY}${B_VERT}${RESET}  ${C_PRIMARY}${BOLD}DISTRO COMPATIBILITY (Arch / Fedora / Debian):${RESET}${SPACES:0:pad_h3}${C_DARK_GRAY}${B_VERT}${RESET}${NL}"
            for d in "${DET_DISTRO[@]}"; do
                local pad_d=$((INNER_W - ${#d} - 5))
                [ "$pad_d" -lt 0 ] && pad_d=0
                body+="  ${C_DARK_GRAY}${B_VERT}${RESET}   • ${d:0:$((INNER_W - 5))}${SPACES:0:pad_d}${C_DARK_GRAY}${B_VERT}${RESET}${NL}"
            done

            body+="  ${C_DARK_GRAY}${B_BOT_L}${HLINE}${B_BOT_R}${RESET}${NL}"
            DETAIL_CARD_BODY[i]="$body"
        done
        REBUILD_NEEDED=0
    }

    render_detail_screen() {
        local cur_k="${MODULE_KEYS[cursor_idx]}"
        local is_sel="${SELECTED[$cur_k]}"
        local badge="${C_GREEN}[✔] SELECTED / ENABLED${RESET}"
        [ "$is_sel" -eq 0 ] && badge="${C_GRAY}[ ] UNSELECTED / DISABLED${RESET}"

        local buf=$'\033[H'
        buf+="$banner"
        buf+="${DETAIL_CARD_TOP[cursor_idx]}"
        buf+="${badge} ${C_DARK_GRAY}${B_VERT}${RESET}${NL}"
        buf+="${DETAIL_CARD_BODY[cursor_idx]}"
        buf+="${DETAIL_CARD_BOT}"
        buf+=$'\033[J'
        printf "%s" "$buf"
    }

    rebuild_selection_caches

    while true; do
        if [ "$REBUILD_NEEDED" -eq 1 ]; then
            rebuild_selection_caches
        fi

        # Detailed Inspection Screen Mode
        if [ "$in_detail_view" -eq 1 ]; then
            render_detail_screen
            read_key
            case "$KEY_PRESSED" in
                "h"|"H"|$'\x1b[D'|$'\x1bOD'|"q"|"Q"|$'\x1b')
                    in_detail_view=0
                    ;;
                "j"|"J"|$'\x1b[B'|$'\x1bOB')
                    cursor_idx=$(( (cursor_idx + 1) % num_keys ))
                    ;;
                "k"|"K"|$'\x1b[A'|$'\x1bOA')
                    cursor_idx=$(( (cursor_idx - 1 + num_keys) % num_keys ))
                    ;;
                " ")
                    local cur_k="${MODULE_KEYS[cursor_idx]}"
                    if [ "${SELECTED[$cur_k]}" -eq 1 ]; then
                        SELECTED["$cur_k"]=0
                    else
                        SELECTED["$cur_k"]=1
                    fi
                    ;;
                ""|$'\n'|$'\r')
                    in_detail_view=0
                    ;;
            esac
            continue
        fi

        local header_lines=17
        [ "$LINES" -ge 28 ] && header_lines=24
        local max_visible=$((LINES - header_lines))
        [ "$max_visible" -lt 6 ] && max_visible=6
        [ "$max_visible" -gt "$num_keys" ] && max_visible="$num_keys"

        # Adjust scrolling window
        if [ "$cursor_idx" -lt "$scroll_offset" ]; then
            scroll_offset="$cursor_idx"
        elif [ "$cursor_idx" -ge $((scroll_offset + max_visible)) ]; then
            scroll_offset=$((cursor_idx - max_visible + 1))
        fi

        # Build entire frame in memory with precalculated rows
        local buf=$'\033[H'"$HEADER_BUF"

        # Scroll indicator top
        if [ "$scroll_offset" -gt 0 ]; then
            local scroll_up="          ▲  $scroll_offset more components above  ▲"
            local spad=$((INNER_W - ${#scroll_up}))
            [ "$spad" -lt 0 ] && spad=0
            buf+="  ${C_DARK_GRAY}${B_VERT}${C_GRAY}${scroll_up}${SPACES:0:spad}${C_DARK_GRAY}${B_VERT}${RESET}${NL}"
        fi

        local end_idx=$((scroll_offset + max_visible))
        [ "$end_idx" -gt "$num_keys" ] && end_idx="$num_keys"

        for ((i = scroll_offset; i < end_idx; i++)); do
            local key="${MODULE_KEYS[i]}"
            if [ "$i" -eq "$cursor_idx" ]; then
                [ "${SELECTED[$key]}" -eq 1 ] && buf+="${ROW_SEL_ACTIVE[i]}" || buf+="${ROW_UNSEL_ACTIVE[i]}"
            else
                [ "${SELECTED[$key]}" -eq 1 ] && buf+="${ROW_SEL_INACTIVE[i]}" || buf+="${ROW_UNSEL_INACTIVE[i]}"
            fi
        done

        # Scroll indicator bottom
        if [ "$end_idx" -lt "$num_keys" ]; then
            local rem=$((num_keys - end_idx))
            local scroll_dn="          ▼  $rem more components below  ▼"
            local spad=$((INNER_W - ${#scroll_dn}))
            [ "$spad" -lt 0 ] && spad=0
            buf+="  ${C_DARK_GRAY}${B_VERT}${C_GRAY}${scroll_dn}${SPACES:0:spad}${C_DARK_GRAY}${B_VERT}${RESET}${NL}"
        fi

        buf+="$DIVIDER_ROW"
        buf+="${DESC_ROWS[cursor_idx]}"
        buf+="$BOTTOM_ROW"
        buf+="$FOOTER_ROW"
        buf+=$'\033[J'

        # Single atomic write to terminal
        printf "%s" "$buf"

        # Read key or consume pending key
        if [ "$has_pending" -eq 1 ]; then
            KEY_PRESSED="$pending_key"
            has_pending=0
            pending_key=""
        else
            read_key
        fi

        case "$KEY_PRESSED" in
            "l"|"L"|$'\x1b[C'|$'\x1bOC'|"i"|"I")
                in_detail_view=1
                ;;
            $'\x1b[A'|$'\x1bOA'|"k"|"K")
                [ "$cursor_idx" -gt 0 ] && cursor_idx=$((cursor_idx - 1))
                while read -t 0; do
                    read_key || break
                    case "$KEY_PRESSED" in
                        $'\x1b[A'|$'\x1bOA'|"k"|"K")
                            [ "$cursor_idx" -gt 0 ] && cursor_idx=$((cursor_idx - 1))
                            ;;
                        *)
                            pending_key="$KEY_PRESSED"
                            has_pending=1
                            break
                            ;;
                    esac
                done
                ;;
            $'\x1b[B'|$'\x1bOB'|"j"|"J")
                [ "$cursor_idx" -lt $((num_keys - 1)) ] && cursor_idx=$((cursor_idx + 1))
                while read -t 0; do
                    read_key || break
                    case "$KEY_PRESSED" in
                        $'\x1b[B'|$'\x1bOB'|"j"|"J")
                            [ "$cursor_idx" -lt $((num_keys - 1)) ] && cursor_idx=$((cursor_idx + 1))
                            ;;
                        *)
                            pending_key="$KEY_PRESSED"
                            has_pending=1
                            break
                            ;;
                    esac
                done
                ;;
            $'\x1b[5~') # Page Up
                cursor_idx=$((cursor_idx - max_visible))
                [ "$cursor_idx" -lt 0 ] && cursor_idx=0
                ;;
            $'\x1b[6~') # Page Down
                cursor_idx=$((cursor_idx + max_visible))
                [ "$cursor_idx" -ge "$num_keys" ] && cursor_idx=$((num_keys - 1))
                ;;
            $'\x1b[H'|$'\x1b[1~'|$'\x1bOH'|"g") # Home / top
                cursor_idx=0
                ;;
            $'\x1b[F'|$'\x1b[4~'|$'\x1bOF'|"G") # End / bottom
                cursor_idx=$((num_keys - 1))
                ;;
            " ")
                local cur_k="${MODULE_KEYS[cursor_idx]}"
                if [ "${SELECTED[$cur_k]}" -eq 1 ]; then
                    SELECTED["$cur_k"]=0
                else
                    SELECTED["$cur_k"]=1
                fi
                ;;
            "1")
                apply_preset "all"
                ;;
            "2")
                apply_preset "cli"
                ;;
            "3")
                apply_preset "desktop"
                ;;
            "a"|"A")
                apply_preset "all"
                ;;
            "n"|"N")
                apply_preset "none"
                ;;
            "m"|"M")
                if [ "$MODE" = "link" ]; then
                    MODE="copy"
                else
                    MODE="link"
                fi
                rebuild_selection_caches
                ;;
            "d"|"D")
                if [ "$DRY_RUN" = true ]; then
                    DRY_RUN=false
                else
                    DRY_RUN=true
                fi
                rebuild_selection_caches
                ;;
            ""|$'\n'|$'\r')
                # Count selected items
                local sel_count=0
                for k in "${MODULE_KEYS[@]}"; do
                    [ "${SELECTED[$k]}" -eq 1 ] && sel_count=$((sel_count + 1))
                done

                if [ "$sel_count" -eq 0 ]; then
                    continue
                fi
                break
                ;;
            "q"|"Q"|$'\x1b')
                cleanup_terminal
                echo -e "\n${C_YELLOW}Installation cancelled by user.${RESET}"
                exit 0
                ;;
        esac
    done
}

# Confirmation Screen
run_confirmation_tui() {
    clear
    update_terminal_size

    while true; do
        local buf=""
        buf+=$'\033[H'
        buf+="${NL}  ${C_PRIMARY}${B_TOP_L}${HLINE}${B_TOP_R}${RESET}${NL}"

        pad_string "            CONFIRM INSTALLATION ── OmarchIt - The Sanjith Way            " "$INNER_W"
        buf+="  ${C_PRIMARY}${B_VERT}${BOLD}${C_WHITE}${PAD_RESULT}${RESET}${C_PRIMARY}${B_VERT}${RESET}${NL}"
        buf+="  ${C_PRIMARY}${B_DIV_L}${HLINE}${B_DIV_R}${RESET}${NL}"

        # Summary Info
        local mode_desc="Symlink (Safe timestamped backups enabled)"
        [ "$MODE" = "copy" ] && mode_desc="Copy files directly to destination"
        local dry_desc="No (Files will be modified)"
        [ "$DRY_RUN" = true ] && dry_desc="${C_RED}Yes (No changes will be written)${RESET}"

        local lines=(
            "  ${BOLD}Distribution:${RESET}      $DISTRO_NAME ($PKG_MGR)"
            "  ${BOLD}Deployment Mode:${RESET}   $mode_desc"
            "  ${BOLD}Target Directory:${RESET}  $TARGET_DIR"
            "  ${BOLD}Dry Run:${RESET}           $dry_desc"
            ""
            "  ${BOLD}Selected Components:${RESET}"
        )

        for l in "${lines[@]}"; do
            pad_string "$l" "$INNER_W"
            buf+="  ${C_PRIMARY}${B_VERT}${RESET}${PAD_RESULT}${C_PRIMARY}${B_VERT}${RESET}${NL}"
        done

        local count=0
        for k in "${MODULE_KEYS[@]}"; do
            if [ "${SELECTED[$k]}" -eq 1 ]; then
                count=$((count + 1))
                local item_line="    ${C_GREEN}✔${RESET} ${MODULE_NAMES[$k]} ${C_GRAY}(${MODULE_TAGS[$k]})${RESET}"
                pad_string "$item_line" "$INNER_W"
                buf+="  ${C_PRIMARY}${B_VERT}${RESET}${PAD_RESULT}${C_PRIMARY}${B_VERT}${RESET}${NL}"
            fi
        done

        pad_string "" "$INNER_W"
        buf+="  ${C_PRIMARY}${B_VERT}${RESET}${PAD_RESULT}${C_PRIMARY}${B_VERT}${RESET}${NL}"
        buf+="  ${C_PRIMARY}${B_DIV_L}${HLINE}${B_DIV_R}${RESET}${NL}"

        local prompt="  [Enter / y] Start Installation   [b] Back to Selection   [q] Cancel"
        pad_string "$prompt" "$INNER_W"
        buf+="  ${C_PRIMARY}${B_VERT}${BOLD}${C_WHITE}${PAD_RESULT}${RESET}${C_PRIMARY}${B_VERT}${RESET}${NL}"
        buf+="  ${C_PRIMARY}${B_BOT_L}${HLINE}${B_BOT_R}${RESET}${NL}"

        printf "%s" "$buf"

        read_key
        case "$KEY_PRESSED" in
            ""|$'\n'|$'\r'|"y"|"Y")
                return 0
                ;;
            "b"|"B"|$'\x1b')
                return 1
                ;;
            "q"|"Q")
                cleanup_terminal
                echo -e "\n${C_YELLOW}Installation cancelled by user.${RESET}"
                exit 0
                ;;
        esac
    done
}

# Live Installer TUI
declare -a LIVE_LOGS=()
MAX_LIVE_LOGS=5

add_live_log() {
    local msg="$1"
    LIVE_LOGS+=("$msg")
    if [ "${#LIVE_LOGS[@]}" -gt "$MAX_LIVE_LOGS" ]; then
        LIVE_LOGS=("${LIVE_LOGS[@]:1}")
    fi
}

render_installer_frame() {
    local step_num="$1"
    local total_steps="$2"
    local percent="$3"
    local current_task="$4"

    update_terminal_size

    local buf=""
    buf+=$'\033[H'
    buf+="${NL}  ${C_PRIMARY}${B_TOP_L}${HLINE}${B_TOP_R}${RESET}${NL}"

    pad_string "             OMARCHIT INSTALLER ── The Sanjith Way (RUNNING)             " "$INNER_W"
    buf+="  ${C_PRIMARY}${B_VERT}${BOLD}${C_WHITE}${PAD_RESULT}${RESET}${C_PRIMARY}${B_VERT}${RESET}${NL}"
    buf+="  ${C_PRIMARY}${B_DIV_L}${HLINE}${B_DIV_R}${RESET}${NL}"

    # Progress Bar (pre-sliced strings, 0 forks)
    local bar_len=30
    local filled=$((percent * bar_len / 100))
    local empty=$((bar_len - filled))
    local bar_str="${PROGRESS_FILLED:0:filled}${PROGRESS_EMPTY:0:empty}"
    local prog_line="  Overall Progress: ${C_PRIMARY}[${bar_str}]${RESET} ${BOLD}${percent}%%${RESET} (Step ${step_num}/${total_steps})"
    pad_string "$prog_line" "$INNER_W"
    buf+="  ${C_PRIMARY}${B_VERT}${RESET}${PAD_RESULT}${C_PRIMARY}${B_VERT}${RESET}${NL}"
    buf+="  ${C_PRIMARY}${B_DIV_L}${HLINE}${B_DIV_R}${RESET}${NL}"

    # Step checklist
    local s1="[ ] 1. System & Distribution Environment ($DISTRO_NAME)"
    local s2="[ ] 2. System Package Prerequisites ($PKG_MGR)"
    local s3="[ ] 3. Deploy Selected Dotfiles"
    local s4="[ ] 4. ACPI Power Rules & Script Permissions"
    local s5="[ ] 5. External Zsh Plugins"
    local s6="[ ] 6. Final Health Check"

    # Update step icons based on current step_num
    [ "$step_num" -gt 1 ] && s1="${C_GREEN}[✔]${RESET} 1. System & Distribution Environment ($DISTRO_NAME)" || [ "$step_num" -eq 1 ] && s1="${C_YELLOW}[●]${RESET} 1. System & Distribution Environment ($DISTRO_NAME)"
    [ "$step_num" -gt 2 ] && s2="${C_GREEN}[✔]${RESET} 2. System Package Prerequisites ($PKG_MGR)" || [ "$step_num" -eq 2 ] && s2="${C_YELLOW}[●]${RESET} 2. System Package Prerequisites ($PKG_MGR)"
    [ "$step_num" -gt 3 ] && s3="${C_GREEN}[✔]${RESET} 3. Deploy Selected Dotfiles" || [ "$step_num" -eq 3 ] && s3="${C_YELLOW}[●]${RESET} 3. Deploy Selected Dotfiles"
    [ "$step_num" -gt 4 ] && s4="${C_GREEN}[✔]${RESET} 4. ACPI Power Rules & Script Permissions" || [ "$step_num" -eq 4 ] && s4="${C_YELLOW}[●]${RESET} 4. ACPI Power Rules & Script Permissions"
    [ "$step_num" -gt 5 ] && s5="${C_GREEN}[✔]${RESET} 5. External Zsh Plugins" || [ "$step_num" -eq 5 ] && s5="${C_YELLOW}[●]${RESET} 5. External Zsh Plugins"
    [ "$step_num" -gt 6 ] && s6="${C_GREEN}[✔]${RESET} 6. Final Health Check" || [ "$step_num" -eq 6 ] && s6="${C_YELLOW}[●]${RESET} 6. Final Health Check"

    local step_lines=("  $s1" "  $s2" "  $s3" "  $s4" "  $s5" "  $s6")
    for sl in "${step_lines[@]}"; do
        pad_string "$sl" "$INNER_W"
        buf+="  ${C_PRIMARY}${B_VERT}${RESET}${PAD_RESULT}${C_PRIMARY}${B_VERT}${RESET}${NL}"
    done

    buf+="  ${C_PRIMARY}${B_DIV_L}${HLINE}${B_DIV_R}${RESET}${NL}"

    # Current Task
    local task_line="  ${C_ACCENT}Current:${RESET} ${current_task}"
    pad_string "$task_line" "$INNER_W"
    buf+="  ${C_PRIMARY}${B_VERT}${RESET}${PAD_RESULT}${C_PRIMARY}${B_VERT}${RESET}${NL}"
    buf+="  ${C_PRIMARY}${B_DIV_L}${HLINE}${B_DIV_R}${RESET}${NL}"

    # Recent Live Logs
    for ((l = 0; l < MAX_LIVE_LOGS; l++)); do
        local log_entry="${LIVE_LOGS[l]:-}"
        local entry_fmt="    ${C_GRAY}•${RESET} $log_entry"
        [ -z "$log_entry" ] && entry_fmt=""
        pad_string "$entry_fmt" "$INNER_W"
        buf+="  ${C_PRIMARY}${B_VERT}${RESET}${PAD_RESULT}${C_PRIMARY}${B_VERT}${RESET}${NL}"
    done

    buf+="  ${C_PRIMARY}${B_BOT_L}${HLINE}${B_BOT_R}${RESET}${NL}"

    printf "%s" "$buf"
}

run_installer_execution() {
    local total_steps=6
    clear

    # Step 1: Detect Distro
    add_live_log "Detected $DISTRO_NAME using $PKG_MGR"
    render_installer_frame 1 "$total_steps" 15 "Detected $DISTRO_NAME"

    # Step 2: Prerequisites
    if [ "${SELECTED['prereqs']}" -eq 1 ]; then
        render_installer_frame 2 "$total_steps" 30 "Verifying & installing packages via $PKG_MGR..."
        install_system_prerequisites "add_live_log"
        render_installer_frame 2 "$total_steps" 35 "Prerequisites ready"
    else
        add_live_log "Skipping prerequisites (not selected)"
        render_installer_frame 2 "$total_steps" 35 "Prerequisites skipped"
    fi

    # Step 3: Deploy dotfiles
    render_installer_frame 3 "$total_steps" 45 "Indexing dotfiles for deployment..."
    mapfile -t all_dotfiles < <(find "$DOTFILES_DIR" \( -type f -o -type l \) | sort)

    local target_files=()
    for f in "${all_dotfiles[@]}"; do
        local rel="${f#$DOTFILES_DIR/}"
        get_module_for_path "$rel"
        if [ "${SELECTED[$MODULE_RESULT]:-0}" -eq 1 ]; then
            target_files+=("$f")
        fi
    done

    local total_f="${#target_files[@]}"
    local f_idx=0
    for f in "${target_files[@]}"; do
        f_idx=$((f_idx + 1))
        local pct=$((45 + f_idx * 30 / (total_f > 0 ? total_f : 1)))
        local rel="${f#$DOTFILES_DIR/}"
        render_installer_frame 3 "$total_steps" "$pct" "Deploying: $rel ($f_idx/$total_f)"
        deploy_single_item "$f" "add_live_log"
    done
    render_installer_frame 3 "$total_steps" 75 "Dotfiles deployed ($DEPLOYED_COUNT items)"

    # Step 4: Hardware & power profile rules
    if [ "${SELECTED['powerprofiles']}" -eq 1 ]; then
        render_installer_frame 4 "$total_steps" 80 "Configuring power profile scripts and udev rules..."
        configure_hardware_rules "add_live_log"
    else
        add_live_log "Skipping power profile rules (not selected)"
        render_installer_frame 4 "$total_steps" 85 "Hardware rules skipped"
    fi

    # Step 5: External Zsh Plugins
    if [ "${SELECTED['zsh_plugins']}" -eq 1 ]; then
        render_installer_frame 5 "$total_steps" 90 "Fetching external Zsh plugins..."
        install_zsh_plugins "add_live_log"
    else
        add_live_log "Skipping external Zsh plugins (not selected)"
        render_installer_frame 5 "$total_steps" 95 "Zsh plugins skipped"
    fi

    # Step 6: Sanity Check
    render_installer_frame 6 "$total_steps" 100 "Finalizing deployment..."
}

# Completion Screen
run_completion_screen() {
    clear
    update_terminal_size

    local buf=""
    buf+=$'\033[H'
    buf+="${NL}  ${C_GREEN}${B_TOP_L}${HLINE}${B_TOP_R}${RESET}${NL}"

    pad_string "      🎉  OMARCHIT INSTALLED SUCCESSFULLY! (The Sanjith Way)  🎉      " "$INNER_W"
    buf+="  ${C_GREEN}${B_VERT}${BOLD}${C_GREEN}${PAD_RESULT}${RESET}${C_GREEN}${B_VERT}${RESET}${NL}"
    buf+="  ${C_GREEN}${B_DIV_L}${HLINE}${B_DIV_R}${RESET}${NL}"

    local stats_lines=(
        "  ${BOLD}Statistics & Summary:${RESET}"
        "    ${C_GREEN}✔${RESET} Dotfiles Deployed:    ${BOLD}$DEPLOYED_COUNT${RESET} files (Mode: $MODE)"
        "    ${C_GREEN}✔${RESET} Timestamped Backups: ${BOLD}$BACKUP_COUNT${RESET} existing files protected"
        "    ${C_GREEN}✔${RESET} External Plugins:    ${BOLD}$PLUGINS_CLONED${RESET} Zsh plugins installed"
        "    ${C_GREEN}✔${RESET} Distribution:        $DISTRO_NAME ($PKG_MGR)"
        ""
        "  ${BOLD}Recommended Next Steps:${RESET}"
        "    • Shell: If your default shell is not Zsh, run:"
        "        ${C_PRIMARY}chsh -s \$(which zsh)${RESET}  (or test with ${C_PRIMARY}exec zsh${RESET})"
        "    • Hyprland: If currently inside Hyprland, reload with:"
        "        ${C_PRIMARY}hyprctl reload${RESET} or press ${C_PRIMARY}Super + Shift + R${RESET}"
        "    • Themes: Switch Omarchy theme anytime with:"
        "        ${C_PRIMARY}omarchy theme set hrc${RESET}  or  ${C_PRIMARY}omarchy theme set mm93${RESET}"
        "    • Documentation: Check ${C_ACCENT}docs/README.md${RESET} for 27 deep-dive guides!"
    )

    for sl in "${stats_lines[@]}"; do
        pad_string "$sl" "$INNER_W"
        buf+="  ${C_GREEN}${B_VERT}${RESET}${PAD_RESULT}${C_GREEN}${B_VERT}${RESET}${NL}"
    done

    buf+="  ${C_GREEN}${B_BOT_L}${HLINE}${B_BOT_R}${RESET}${NL}${NL}"
    buf+="  ${C_PRIMARY}${BOLD}Press [Enter] or [q] to exit installer...${RESET}${NL}"

    printf "%s" "$buf"

    while true; do
        read_key
        case "$KEY_PRESSED" in
            ""|$'\n'|$'\r'|"q"|"Q"|$'\x1b')
                break
                ;;
        esac
    done

    cleanup_terminal
}

# ------------------------------------------------------------------------------
# Non-Interactive / Batch Execution
# ------------------------------------------------------------------------------
run_batch_installer() {
    echo "=========================================================="
    echo "              OmarchIt - The Sanjith Way"
    echo "=========================================================="
    log_info "Detected OS: $DISTRO_NAME (Family: $PKG_FAMILY, PkgMgr: $PKG_MGR)"
    log_info "Source: $DOTFILES_DIR"
    log_info "Destination: $TARGET_DIR"
    log_info "Mode: $MODE"
    if [ "$DRY_RUN" = true ]; then
        log_warn "Dry run mode active - no filesystem changes will be made."
    fi
    echo ""

    if [ "$INSTALL_PREREQS_CLI" = true ]; then
        log_info "Installing prerequisites for $DISTRO_NAME..."
        install_system_prerequisites "log_info"
    fi

    log_info "Deploying dotfiles..."
    mapfile -t all_dotfiles < <(find "$DOTFILES_DIR" \( -type f -o -type l \) | sort)
    for f in "${all_dotfiles[@]}"; do
        local rel="${f#$DOTFILES_DIR/}"
        get_module_for_path "$rel"
        if [ "${SELECTED[$MODULE_RESULT]:-0}" -eq 1 ]; then
            deploy_single_item "$f" "log_info"
        fi
    done

    if [ "${SELECTED['powerprofiles']}" -eq 1 ]; then
        configure_hardware_rules "log_info"
    fi

    if [ "$INSTALL_PLUGINS_CLI" = true ] || [ "${SELECTED['zsh_plugins']}" -eq 1 ]; then
        install_zsh_plugins "log_info"
    fi

    echo ""
    log_success "Dotfiles deployment complete! ($DEPLOYED_COUNT files deployed, $BACKUP_COUNT backups created)"
}

# ------------------------------------------------------------------------------
# Command Line Argument Parsing
# ------------------------------------------------------------------------------
parse_arguments() {
    for arg in "$@"; do
        case "$arg" in
            --copy)
                MODE="copy"
                ;;
            --link)
                MODE="link"
                ;;
            --dry-run)
                DRY_RUN=true
                ;;
            --plugins)
                INSTALL_PLUGINS_CLI=true
                SELECTED["zsh_plugins"]=1
                ;;
            --prereqs|--deps)
                INSTALL_PREREQS_CLI=true
                SELECTED["prereqs"]=1
                ;;
            --all)
                apply_preset "all"
                ;;
            -y|--yes|--batch)
                NON_INTERACTIVE=true
                RUN_TUI=false
                ;;
            --no-tui)
                RUN_TUI=false
                ;;
            -h|--help)
                echo "OmarchIt - The Sanjith Way"
                echo "Dotfiles & Workspace Suite Installer"
                echo ""
                echo "Usage: ./install.sh [OPTIONS]"
                echo ""
                echo "Interactive Mode:"
                echo "  ./install.sh                Launch creative interactive TUI selection"
                echo ""
                echo "Options:"
                echo "  --link       Symlink dotfiles into home directory (default)"
                echo "  --copy       Copy dotfiles into home directory instead of symlinking"
                echo "  --dry-run    Show actions without making changes"
                echo "  --plugins    Clone external Zsh plugins"
                echo "  --prereqs    Install system prerequisites for detected distribution"
                echo "  --all        Select all components"
                echo "  -y, --yes    Non-interactive mode (accept defaults and proceed)"
                echo "  --no-tui     Run in batch mode without interactive TUI"
                echo "  -h, --help   Show this help message"
                exit 0
                ;;
            *)
                log_err "Unknown option: $arg"
                echo "Run './install.sh --help' for usage."
                exit 1
                ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# Main Entrypoint
# ------------------------------------------------------------------------------
main() {
    parse_arguments "$@"

    # Auto-detect if TUI is possible
    if [ "$IS_TTY" = false ] || [ "$NON_INTERACTIVE" = true ]; then
        RUN_TUI=false
    fi

    if [ "$RUN_TUI" = true ]; then
        while true; do
            run_selection_tui
            if run_confirmation_tui; then
                break
            fi
            # If user pressed 'b' in confirmation, loop back to selection TUI
        done

        run_installer_execution
        run_completion_screen
    else
        run_batch_installer
    fi
}

main "$@"
