#!/usr/bin/env bash
#
# Omarchy Dotfiles Installer & Symlinker
# Usage: ./install.sh [--link | --copy] [--dry-run] [--plugins]
#

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/dotfiles" && pwd)"
TARGET_DIR="${HOME}"
MODE="link" # default: symlink
DRY_RUN=false
INSTALL_PLUGINS=false

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_err() { echo -e "${RED}[ERROR]${NC} $*"; }

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
            INSTALL_PLUGINS=true
            ;;
        -h|--help)
            echo "Usage: ./install.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --link       Symlink dotfiles into home directory (default)"
            echo "  --copy       Copy dotfiles into home directory instead of symlinking"
            echo "  --dry-run    Show actions without making changes"
            echo "  --plugins    Clone external zsh plugins & omarchy plugins"
            echo "  -h, --help   Show this help message"
            exit 0
            ;;
        *)
            log_err "Unknown option: $arg"
            exit 1
            ;;
    esac
done

deploy_file() {
    local src="$1"
    local rel_path="${src#$DOTFILES_DIR/}"
    local dest="$TARGET_DIR/$rel_path"
    local dest_dir
    dest_dir="$(dirname "$dest")"

    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY-RUN] Deploy $rel_path -> $dest ($MODE)"
        return 0
    fi

    mkdir -p "$dest_dir"

    # If destination exists and differs, create a timestamped backup
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        if [ "$MODE" = "link" ] && [ -L "$dest" ] && [ "$(readlink -f "$dest")" = "$(readlink -f "$src")" ]; then
            log_info "Already linked: $rel_path"
            return 0
        fi

        # Backup existing file if different
        if ! cmp -s "$src" "$dest" 2>/dev/null; then
            local backup_path="${dest}.backup.$(date +%Y%m%d%H%M%S)"
            log_warn "Backing up existing $dest to $backup_path"
            mv "$dest" "$backup_path"
        else
            rm -rf "$dest"
        fi
    fi

    if [ "$MODE" = "link" ]; then
        ln -snf "$src" "$dest"
        log_success "Linked $rel_path -> $dest"
    else
        cp -p "$src" "$dest"
        log_success "Copied $rel_path -> $dest"
    fi
}

echo "=========================================================="
echo "         Omarchy Dotfiles Deployment Script"
echo "=========================================================="
log_info "Source: $DOTFILES_DIR"
log_info "Destination: $TARGET_DIR"
log_info "Mode: $MODE"
if [ "$DRY_RUN" = true ]; then
    log_warn "Dry run mode active - no filesystem changes will be made."
fi
echo ""

# Deploy files
find "$DOTFILES_DIR" -type f | while read -r file; do
    deploy_file "$file"
done

# Ensure local bin scripts are executable
if [ "$DRY_RUN" = false ]; then
    chmod +x "$TARGET_DIR/.local/bin/omarchy-powerprofiles-"* 2>/dev/null || true
    chmod +x "$TARGET_DIR/.config/omarchy/plugins/sanjith.power/"*.sh 2>/dev/null || true
fi

# Optional zsh plugins installation
if [ "$INSTALL_PLUGINS" = true ]; then
    echo ""
    log_info "Ensuring Zsh plugins exist in ~/.zsh/plugins/..."
    mkdir -p "$TARGET_DIR/.zsh/plugins"

    declare -A ZSH_PLUGINS=(
        ["fzf-tab"]="https://github.com/Aloxaf/fzf-tab"
        ["zsh-autopair"]="https://github.com/hlissner/zsh-autopair"
        ["zsh-autosuggestions"]="https://github.com/zsh-users/zsh-autosuggestions"
        ["zsh-syntax-highlighting"]="https://github.com/zsh-users/zsh-syntax-highlighting"
    )

    for plugin in "${!ZSH_PLUGINS[@]}"; do
        pdir="$TARGET_DIR/.zsh/plugins/$plugin"
        if [ ! -d "$pdir" ]; then
            log_info "Cloning $plugin..."
            [ "$DRY_RUN" = false ] && git clone --depth=1 "${ZSH_PLUGINS[$plugin]}" "$pdir"
        else
            log_info "Plugin $plugin already present."
        fi
    done
fi

echo ""
log_success "Dotfiles deployment complete!"
