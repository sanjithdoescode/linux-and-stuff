#!/usr/bin/env bash
#
# ==============================================================================
#             OMARCHY DOTFILES & WORKSPACE SUITE INSTALLER
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
BOLD='\033[1m'
DIM='\033[2m'
ITALIC='\033[3m'
UNDERLINE='\033[4m'
RESET='\033[0m'

# Palette
C_PRIMARY='\033[38;5;51m'     # Bright Cyan / Neon Blue
C_ACCENT='\033[38;5;141m'     # Soft Purple / Lavender
C_GREEN='\033[38;5;82m'       # Vibrant Green
C_YELLOW='\033[38;5;214m'     # Amber / Gold
C_RED='\033[38;5;203m'        # Soft Coral Red
C_GRAY='\033[38;5;244m'       # Medium Gray
C_DARK_GRAY='\033[38;5;238m'  # Border Gray
C_WHITE='\033[38;5;255m'      # Pure White
C_BG_HIGHLIGHT='\033[48;5;236m' # Selection background

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
get_module_for_path() {
    local rel="$1"
    case "$rel" in
        .zshrc|.config/zsh*|.config/starship.toml)
            echo "zsh" ;;
        .bashrc|.bash_profile|.profile)
            echo "bash" ;;
        .tmux.conf|.config/tmux*)
            echo "tmux" ;;
        .config/ghostty*)
            echo "ghostty" ;;
        .config/kitty*|.config/alacritty*|.config/foot*)
            echo "terminals" ;;
        .config/nvim*)
            echo "nvim" ;;
        .config/helix*)
            echo "helix" ;;
        .config/git*|.config/lazygit*|.config/mise*)
            echo "git_tools" ;;
        .config/btop*)
            echo "btop" ;;
        .config/hypr*|.config/hyprland-preview-share-picker*)
            echo "hyprland" ;;
        .config/wireplumber*|.config/imv*|.config/tensaku*|.config/voxtype*)
            echo "desktop_media" ;;
        .config/autostart*|.config/fcitx5*|.config/gtk-3.0*|.config/user-dirs.dirs|.config/mimeapps.list|.config/xdg-terminals.list|.config/chromium-flags.conf|.config/brave-origin-flags.conf|.XCompose)
            echo "desktop_common" ;;
        .config/omarchy*)
            echo "omarchy_core" ;;
        .local/bin/omarchy-powerprofiles-*)
            echo "powerprofiles" ;;
        .local/bin/antigravity-cli)
            echo "antigravity" ;;
        *)
            echo "other" ;;
    esac
}

# ------------------------------------------------------------------------------
# Terminal Control & Raw Mode Handlers
# ------------------------------------------------------------------------------
ORIGINAL_STTY=""

setup_terminal() {
    if [ "$IS_TTY" = true ]; then
        ORIGINAL_STTY="$(stty -g 2>/dev/null || true)"
        printf '\033[?25l' # hide cursor
        printf '\033[?1049h' # switch to alternate screen buffer
        clear
    fi
}

cleanup_terminal() {
    if [ "$IS_TTY" = true ]; then
        printf '\033[?1049l' # exit alternate screen buffer
        printf '\033[?25h'   # show cursor
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

# Read a single keypress cleanly including escape sequences
read_key() {
    local key=""
    local rest=""
    local more=""

    IFS= read -rsn1 key 2>/dev/null || true
    if [[ "$key" == $'\x1b' ]]; then
        read -rsn2 -t 0.05 rest 2>/dev/null || rest=""
        key+="$rest"
        if [[ "$key" == $'\x1b['* ]]; then
            read -rsn1 -t 0.05 more 2>/dev/null || more=""
            key+="$more"
        fi
    fi
    echo "$key"
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
            echo "zsh fzf bat ripgrep zoxide jq fd-find libnotify-bin btop tmux git curl wl-clipboard neovim"
            ;;
        fedora)
            echo "zsh fzf bat eza ripgrep zoxide jq fd-find libnotify btop tmux git curl wl-clipboard neovim fastfetch lazygit"
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

    # Check for missing packages
    local missing=()
    for p in "${pkgs[@]}"; do
        case "$PKG_FAMILY" in
            arch)
                if ! pacman -Q "$p" >/dev/null 2>&1 && ! command -v "$p" >/dev/null 2>&1; then
                    missing+=("$p")
                fi
                ;;
            debian)
                if ! dpkg -s "$p" >/dev/null 2>&1 && ! command -v "$p" >/dev/null 2>&1; then
                    missing+=("$p")
                fi
                ;;
            fedora)
                if ! rpm -q "$p" >/dev/null 2>&1 && ! command -v "$p" >/dev/null 2>&1; then
                    missing+=("$p")
                fi
                ;;
            *)
                if ! command -v "$p" >/dev/null 2>&1; then
                    missing+=("$p")
                fi
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
            if command -v fdfind >/dev/null 2>&1 && [ ! -e "$TARGET_DIR/.local/bin/fd" ]; then
                mkdir -p "$TARGET_DIR/.local/bin"
                ln -sf "$(command -v fdfind)" "$TARGET_DIR/.local/bin/fd"
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

deploy_single_item() {
    local src="$1"
    local rel_path="${src#$DOTFILES_DIR/}"
    local dest="$TARGET_DIR/$rel_path"
    local dest_dir
    dest_dir="$(dirname "$dest")"
    local log_fn="$2"

    if [ "$DRY_RUN" = true ]; then
        "$log_fn" "[DRY-RUN] Deploy $rel_path -> $dest ($MODE)"
        DEPLOYED_COUNT=$((DEPLOYED_COUNT + 1))
        return 0
    fi

    mkdir -p "$dest_dir"

    # Backup logic if file differs
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        if [ "$MODE" = "link" ] && [ "$(readlink -f "$dest" 2>/dev/null)" = "$(readlink -f "$src" 2>/dev/null)" ]; then
            "$log_fn" "Already linked: $rel_path"
            DEPLOYED_COUNT=$((DEPLOYED_COUNT + 1))
            return 0
        fi

        # Backup if content differs
        if ! cmp -s "$src" "$dest" 2>/dev/null; then
            local backup_path="${dest}.backup.$(date +%Y%m%d%H%M%S)"
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
        "$log_fn" "[DRY-RUN] Would set executable permissions and install ACPI udev rule"
        return 0
    fi

    chmod +x "$TARGET_DIR/.local/bin/omarchy-powerprofiles-"* 2>/dev/null || true
    chmod +x "$TARGET_DIR/.config/omarchy/plugins/sanjith.power/"*.sh 2>/dev/null || true

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
}

# ------------------------------------------------------------------------------
# TUI Rendering & Screens
# ------------------------------------------------------------------------------

# Helper to pad text to a exact column width
pad_string() {
    local text="$1"
    local width="$2"
    # Strip ANSI escapes to calculate visual length
    local raw
    raw="$(printf "%b" "$text" | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g")"
    local len="${#raw}"
    local pad=$((width - len))
    if [ "$pad" -gt 0 ]; then
        printf "%b%*s" "$text" "$pad" ""
    else
        printf "%b" "$text"
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

# Selection Menu Screen
run_selection_tui() {
    local cursor_idx=0
    local scroll_offset=0
    local num_keys="${#MODULE_KEYS[@]}"

    setup_terminal
    resume_raw_mode

    while true; do
        local cols lines
        cols="$(tput cols 2>/dev/null || echo 80)"
        lines="$(tput lines 2>/dev/null || echo 24)"
        local box_w=74
        [ "$cols" -lt 76 ] && box_w=$((cols - 2))
        [ "$box_w" -lt 50 ] && box_w=50

        local max_visible=$((lines - 17))
        [ "$max_visible" -lt 6 ] && max_visible=6
        [ "$max_visible" -gt "$num_keys" ] && max_visible="$num_keys"

        # Adjust scrolling window
        if [ "$cursor_idx" -lt "$scroll_offset" ]; then
            scroll_offset="$cursor_idx"
        elif [ "$cursor_idx" -ge $((scroll_offset + max_visible)) ]; then
            scroll_offset=$((cursor_idx - max_visible + 1))
        fi

        # Draw frame (move to top-left)
        printf '\033[H'

        # Banner Header
        printf "%b%s%b\n" "$C_PRIMARY$BOLD" "  ██████╗ ███╗   ███╗ █████╗ ██████╗  ██████╗██╗  ██╗██╗   ██╗" "$RESET"
        printf "%b%s%b\n" "$C_PRIMARY$BOLD" " ██╔═══██╗████╗ ████║██╔══██╗██╔══██╗██╔════╝██║  ██║╚██╗ ██╔╝" "$RESET"
        printf "%b%s%b\n" "$C_ACCENT$BOLD"  " ██║   ██║██╔████╔██║███████║██████╔╝██║     ███████║ ╚████╔╝ " "$RESET"
        printf "%b%s%b\n" "$C_ACCENT$BOLD"  " ╚██████╔╝██║ ╚═╝ ██║██║  ██║██║  ██║╚██████╗██║  ██║   ██║   " "$RESET"
        printf "%b%s%b\n" "$C_WHITE$BOLD"   "  ╚═════╝ ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝   ╚═╝   " "$RESET"
        printf "%b%s%b\n" "$C_GRAY$ITALIC"  "            ── Custom Dotfiles & Workspace Suite ──            " "$RESET"
        echo ""

        # System Info Bar
        local mode_badge="${C_GREEN}Symlink${RESET}"
        [ "$MODE" = "copy" ] && mode_badge="${C_YELLOW}Copy${RESET}"
        local dry_badge=""
        [ "$DRY_RUN" = true ] && dry_badge=" ${C_RED}[DRY-RUN]${RESET}"

        printf "  %bOS:%b %s  %bPkg:%b %s  %bMode:%b %b%b  %bTarget:%b %s\n\n" \
            "$C_ACCENT" "$RESET" "$DISTRO_NAME" \
            "$C_ACCENT" "$RESET" "$PKG_MGR" \
            "$C_ACCENT" "$RESET" "$mode_badge" "$dry_badge" \
            "$C_ACCENT" "$RESET" "$TARGET_DIR"

        # Top border of components box
        local horiz_line
        horiz_line="$(printf "%*s" "$((box_w - 2))" "" | tr ' ' "$B_HORIZ")"
        printf "  %b%s%s%s%b\n" "$C_DARK_GRAY" "$B_TOP_L" "$horiz_line" "$B_TOP_R" "$RESET"

        # Preset Quick Bar inside box
        local preset_content="  Presets: ${C_PRIMARY}[1]${RESET} Full  ${C_PRIMARY}[2]${RESET} CLI  ${C_PRIMARY}[3]${RESET} Desktop  ${C_PRIMARY}[a]${RESET} All  ${C_PRIMARY}[n]${RESET} None"
        local padded_preset
        padded_preset="$(pad_string "$preset_content" "$((box_w - 2))")"
        printf "  %b%s%b%b%b%s%b\n" "$C_DARK_GRAY" "$B_VERT" "$RESET" "$padded_preset" "$C_DARK_GRAY" "$B_VERT" "$RESET"

        # Divider
        printf "  %b%s%s%s%b\n" "$C_DARK_GRAY" "$B_DIV_L" "$horiz_line" "$B_DIV_R" "$RESET"

        # Scroll indicator top
        if [ "$scroll_offset" -gt 0 ]; then
            local scroll_up="          ▲  $scroll_offset more components above  ▲"
            printf "  %b%s%b%s%b%s%b\n" "$C_DARK_GRAY" "$B_VERT" "$C_GRAY" "$(pad_string "$scroll_up" "$((box_w - 2))")" "$C_DARK_GRAY" "$B_VERT" "$RESET"
        fi

        # Items listing
        local end_idx=$((scroll_offset + max_visible))
        [ "$end_idx" -gt "$num_keys" ] && end_idx="$num_keys"

        for ((i = scroll_offset; i < end_idx; i++)); do
            local key="${MODULE_KEYS[i]}"
            local name="${MODULE_NAMES[$key]}"
            local tag="${MODULE_TAGS[$key]}"
            local is_sel="${SELECTED[$key]}"

            local check_box="${C_GREEN}[✔]${RESET}"
            if [ "$is_sel" -eq 0 ]; then
                check_box="${C_GRAY}[ ]${RESET}"
            fi

            local tag_str="${C_GRAY}[$tag]${RESET}"
            local pointer="  "
            local line_format=""

            if [ "$i" -eq "$cursor_idx" ]; then
                pointer="${C_PRIMARY}❯ "
                line_format="${BOLD}${C_WHITE}"
            else
                pointer="  "
                line_format="${C_WHITE}"
            fi

            local item_text="${pointer}${check_box} ${line_format}${name}${RESET}  ${tag_str}"
            local padded_item
            padded_item="$(pad_string "$item_text" "$((box_w - 2))")"

            if [ "$i" -eq "$cursor_idx" ]; then
                printf "  %b%s%b%b%s%b%b%s%b\n" "$C_DARK_GRAY" "$B_VERT" "$C_BG_HIGHLIGHT" "$padded_item" "$RESET" "$C_DARK_GRAY" "$B_VERT" "$RESET"
            else
                printf "  %b%s%b%s%b%s%b\n" "$C_DARK_GRAY" "$B_VERT" "$padded_item" "$C_DARK_GRAY" "$B_VERT" "$RESET"
            fi
        done

        # Scroll indicator bottom
        if [ "$end_idx" -lt "$num_keys" ]; then
            local rem=$((num_keys - end_idx))
            local scroll_dn="          ▼  $rem more components below  ▼"
            printf "  %b%s%b%s%b%s%b\n" "$C_DARK_GRAY" "$B_VERT" "$C_GRAY" "$(pad_string "$scroll_dn" "$((box_w - 2))")" "$C_DARK_GRAY" "$B_VERT" "$RESET"
        fi

        # Divider to Description Box
        printf "  %b%s%s%s%b\n" "$C_DARK_GRAY" "$B_DIV_L" "$horiz_line" "$B_DIV_R" "$RESET"

        # Focused Item Description
        local cur_key="${MODULE_KEYS[cursor_idx]}"
        local cur_desc="${MODULE_DESCS[$cur_key]}"
        local desc_line="  ${C_ACCENT}Info:${RESET} ${cur_desc}"
        # Truncate if longer than box
        local padded_desc
        padded_desc="$(pad_string "$desc_line" "$((box_w - 2))")"
        printf "  %b%s%b%b%b%s%b\n" "$C_DARK_GRAY" "$B_VERT" "$RESET" "$padded_desc" "$C_DARK_GRAY" "$B_VERT" "$RESET"

        # Bottom Border
        printf "  %b%s%s%s%b\n" "$C_DARK_GRAY" "$B_BOT_L" "$horiz_line" "$B_BOT_R" "$RESET"

        # Footer Keys
        printf "  %b[↑/↓/j/k]%b Move  %b[Space]%b Toggle  %b[m]%b Mode  %b[d]%b Dry-Run  %b[Enter]%b Proceed  %b[q]%b Quit\033[K\n" \
            "$C_PRIMARY" "$RESET" "$C_PRIMARY" "$RESET" "$C_PRIMARY" "$RESET" "$C_PRIMARY" "$RESET" "$C_GREEN" "$RESET" "$C_RED" "$RESET"

        # Key Input Handling
        local key_pressed
        key_pressed="$(read_key)"

        case "$key_pressed" in
            $'\x1b[A'|"k"|"K")
                if [ "$cursor_idx" -gt 0 ]; then
                    cursor_idx=$((cursor_idx - 1))
                fi
                ;;
            $'\x1b[B'|"j"|"J")
                if [ "$cursor_idx" -lt $((num_keys - 1)) ]; then
                    cursor_idx=$((cursor_idx + 1))
                fi
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
                ;;
            "d"|"D")
                if [ "$DRY_RUN" = true ]; then
                    DRY_RUN=false
                else
                    DRY_RUN=true
                fi
                ;;
            ""|$'\n'|$'\r')
                # Count selected items
                local sel_count=0
                for k in "${MODULE_KEYS[@]}"; do
                    [ "${SELECTED[$k]}" -eq 1 ] && sel_count=$((sel_count + 1))
                done

                if [ "$sel_count" -eq 0 ]; then
                    # Nothing selected, warn
                    continue
                fi
                break
                ;;
            "q"|"Q")
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
    local cols
    cols="$(tput cols 2>/dev/null || echo 80)"
    local box_w=74
    [ "$cols" -lt 76 ] && box_w=$((cols - 2))
    [ "$box_w" -lt 50 ] && box_w=50

    local horiz_line
    horiz_line="$(printf "%*s" "$((box_w - 2))" "" | tr ' ' "$B_HORIZ")"

    while true; do
        printf '\033[H'
        echo ""
        printf "  %b%s%s%s%b\n" "$C_PRIMARY" "$B_TOP_L" "$horiz_line" "$B_TOP_R" "$RESET"
        local title="                      CONFIRM INSTALLATION                      "
        printf "  %b%s%b%b%s%b%b%s%b\n" "$C_PRIMARY" "$B_VERT" "$BOLD$C_WHITE" "$(pad_string "$title" "$((box_w - 2))")" "$RESET" "$C_PRIMARY" "$B_VERT" "$RESET"
        printf "  %b%s%s%s%b\n" "$C_PRIMARY" "$B_DIV_L" "$horiz_line" "$B_DIV_R" "$RESET"

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
            printf "  %b%s%b%s%b%s%b\n" "$C_PRIMARY" "$B_VERT" "$RESET" "$(pad_string "$l" "$((box_w - 2))")" "$C_PRIMARY" "$B_VERT" "$RESET"
        done

        local count=0
        for k in "${MODULE_KEYS[@]}"; do
            if [ "${SELECTED[$k]}" -eq 1 ]; then
                count=$((count + 1))
                local item_line="    ${C_GREEN}✔${RESET} ${MODULE_NAMES[$k]} ${C_GRAY}(${MODULE_TAGS[$k]})${RESET}"
                printf "  %b%s%b%s%b%s%b\n" "$C_PRIMARY" "$B_VERT" "$RESET" "$(pad_string "$item_line" "$((box_w - 2))")" "$C_PRIMARY" "$B_VERT" "$RESET"
            fi
        done

        printf "  %b%s%b%s%b%s%b\n" "$C_PRIMARY" "$B_VERT" "$RESET" "$(pad_string "" "$((box_w - 2))")" "$C_PRIMARY" "$B_VERT" "$RESET"
        printf "  %b%s%s%s%b\n" "$C_PRIMARY" "$B_DIV_L" "$horiz_line" "$B_DIV_R" "$RESET"

        local prompt="  [Enter / y] Start Installation   [b] Back to Selection   [q] Cancel"
        printf "  %b%s%b%s%b%s%b\n" "$C_PRIMARY" "$B_VERT" "$BOLD$C_WHITE" "$(pad_string "$prompt" "$((box_w - 2))")" "$RESET" "$C_PRIMARY" "$B_VERT" "$RESET"
        printf "  %b%s%s%s%b\n" "$C_PRIMARY" "$B_BOT_L" "$horiz_line" "$B_BOT_R" "$RESET"

        local key
        key="$(read_key)"
        case "$key" in
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
    local cols
    cols="$(tput cols 2>/dev/null || echo 80)"
    local box_w=74
    [ "$cols" -lt 76 ] && box_w=$((cols - 2))
    [ "$box_w" -lt 50 ] && box_w=50

    local horiz_line
    horiz_line="$(printf "%*s" "$((box_w - 2))" "" | tr ' ' "$B_HORIZ")"

    # Move to top-left
    printf '\033[H'

    echo ""
    printf "  %b%s%s%s%b\n" "$C_PRIMARY" "$B_TOP_L" "$horiz_line" "$B_TOP_R" "$RESET"
    local title="                   OMARCHY INSTALLER ── RUNNING                  "
    printf "  %b%s%b%b%s%b%b%s%b\n" "$C_PRIMARY" "$B_VERT" "$BOLD$C_WHITE" "$(pad_string "$title" "$((box_w - 2))")" "$RESET" "$C_PRIMARY" "$B_VERT" "$RESET"
    printf "  %b%s%s%s%b\n" "$C_PRIMARY" "$B_DIV_L" "$horiz_line" "$B_DIV_R" "$RESET"

    # Progress Bar
    local bar_len=30
    local filled=$((percent * bar_len / 100))
    local empty=$((bar_len - filled))
    local bar_str
    bar_str="$(printf "%*s" "$filled" "" | tr ' ' "█")$(printf "%*s" "$empty" "" | tr ' ' "░")"
    local prog_line="  Overall Progress: ${C_PRIMARY}[${bar_str}]${RESET} ${BOLD}${percent}%%${RESET} (Step ${step_num}/${total_steps})"
    printf "  %b%s%b%s%b%s%b\n" "$C_PRIMARY" "$B_VERT" "$RESET" "$(pad_string "$prog_line" "$((box_w - 2))")" "$C_PRIMARY" "$B_VERT" "$RESET"
    printf "  %b%s%s%s%b\n" "$C_PRIMARY" "$B_DIV_L" "$horiz_line" "$B_DIV_R" "$RESET"

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
        printf "  %b%s%b%s%b%s%b\n" "$C_PRIMARY" "$B_VERT" "$RESET" "$(pad_string "$sl" "$((box_w - 2))")" "$C_PRIMARY" "$B_VERT" "$RESET"
    done

    printf "  %b%s%s%s%b\n" "$C_PRIMARY" "$B_DIV_L" "$horiz_line" "$B_DIV_R" "$RESET"

    # Current Task
    local task_line="  ${C_ACCENT}Current:${RESET} ${current_task}"
    printf "  %b%s%b%s%b%s%b\n" "$C_PRIMARY" "$B_VERT" "$RESET" "$(pad_string "$task_line" "$((box_w - 2))")" "$C_PRIMARY" "$B_VERT" "$RESET"
    printf "  %b%s%s%s%b\n" "$C_PRIMARY" "$B_DIV_L" "$horiz_line" "$B_DIV_R" "$RESET"

    # Recent Live Logs
    for ((l = 0; l < MAX_LIVE_LOGS; l++)); do
        local log_entry="${LIVE_LOGS[l]:-}"
        local entry_fmt="    ${C_GRAY}•${RESET} $log_entry"
        [ -z "$log_entry" ] && entry_fmt=""
        printf "  %b%s%b%s%b%s%b\n" "$C_PRIMARY" "$B_VERT" "$RESET" "$(pad_string "$entry_fmt" "$((box_w - 2))")" "$C_PRIMARY" "$B_VERT" "$RESET"
    done

    printf "  %b%s%s%s%b\n" "$C_PRIMARY" "$B_BOT_L" "$horiz_line" "$B_BOT_R" "$RESET"
}

run_installer_execution() {
    local total_steps=6
    clear

    # Step 1: Detect Distro
    add_live_log "Detected $DISTRO_NAME using $PKG_MGR"
    render_installer_frame 1 "$total_steps" 15 "Detected $DISTRO_NAME"
    sleep 0.3

    # Step 2: Prerequisites
    if [ "${SELECTED['prereqs']}" -eq 1 ]; then
        render_installer_frame 2 "$total_steps" 30 "Verifying & installing packages via $PKG_MGR..."
        install_system_prerequisites "add_live_log"
        render_installer_frame 2 "$total_steps" 35 "Prerequisites ready"
    else
        add_live_log "Skipping prerequisites (not selected)"
        render_installer_frame 2 "$total_steps" 35 "Prerequisites skipped"
    fi
    sleep 0.2

    # Step 3: Deploy dotfiles
    render_installer_frame 3 "$total_steps" 45 "Indexing dotfiles for deployment..."
    mapfile -t all_dotfiles < <(find "$DOTFILES_DIR" \( -type f -o -type l \) | sort)

    local target_files=()
    for f in "${all_dotfiles[@]}"; do
        local rel="${f#$DOTFILES_DIR/}"
        local mod
        mod="$(get_module_for_path "$rel")"
        if [ "${SELECTED[$mod]:-0}" -eq 1 ]; then
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
    sleep 0.2

    # Step 4: Hardware & power profile rules
    if [ "${SELECTED['powerprofiles']}" -eq 1 ]; then
        render_installer_frame 4 "$total_steps" 80 "Configuring power profile scripts and udev rules..."
        configure_hardware_rules "add_live_log"
    else
        add_live_log "Skipping power profile rules (not selected)"
        render_installer_frame 4 "$total_steps" 85 "Hardware rules skipped"
    fi
    sleep 0.2

    # Step 5: External Zsh Plugins
    if [ "${SELECTED['zsh_plugins']}" -eq 1 ]; then
        render_installer_frame 5 "$total_steps" 90 "Fetching external Zsh plugins..."
        install_zsh_plugins "add_live_log"
    else
        add_live_log "Skipping external Zsh plugins (not selected)"
        render_installer_frame 5 "$total_steps" 95 "Zsh plugins skipped"
    fi
    sleep 0.2

    # Step 6: Sanity Check
    render_installer_frame 6 "$total_steps" 100 "Finalizing deployment..."
    sleep 0.5
}

# Completion Screen
run_completion_screen() {
    clear
    local cols
    cols="$(tput cols 2>/dev/null || echo 80)"
    local box_w=74
    [ "$cols" -lt 76 ] && box_w=$((cols - 2))
    [ "$box_w" -lt 50 ] && box_w=50

    local horiz_line
    horiz_line="$(printf "%*s" "$((box_w - 2))" "" | tr ' ' "$B_HORIZ")"

    printf '\033[H'
    echo ""
    printf "  %b%s%s%s%b\n" "$C_GREEN" "$B_TOP_L" "$horiz_line" "$B_TOP_R" "$RESET"
    local title="                 🎉  INSTALLATION FINISHED SUCCESSFULLY!  🎉              "
    printf "  %b%s%b%b%s%b%b%s%b\n" "$C_GREEN" "$B_VERT" "$BOLD$C_GREEN" "$(pad_string "$title" "$((box_w - 2))")" "$RESET" "$C_GREEN" "$B_VERT" "$RESET"
    printf "  %b%s%s%s%b\n" "$C_GREEN" "$B_DIV_L" "$horiz_line" "$B_DIV_R" "$RESET"

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
        printf "  %b%s%b%s%b%s%b\n" "$C_GREEN" "$B_VERT" "$RESET" "$(pad_string "$sl" "$((box_w - 2))")" "$C_GREEN" "$B_VERT" "$RESET"
    done

    printf "  %b%s%s%s%b\n" "$C_GREEN" "$B_BOT_L" "$horiz_line" "$B_BOT_R" "$RESET"
    echo ""
    printf "  %bPress [Enter] or [q] to exit installer...%b\n" "$C_PRIMARY$BOLD" "$RESET"

    while true; do
        local k
        k="$(read_key)"
        case "$k" in
            ""|$'\n'|$'\r'|"q"|"Q")
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
    echo "         Omarchy Dotfiles Deployment Script"
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
        local mod
        mod="$(get_module_for_path "$rel")"
        if [ "${SELECTED[$mod]:-0}" -eq 1 ]; then
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
                echo "Omarchy Dotfiles & Workspace Suite Installer"
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
