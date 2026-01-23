#!/bin/bash
# Bootstrap script for dotfiles with Home Manager
# Installs Nix and applies Home Manager configuration
# Uses Determinate Systems installer (works as root and in containers)

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}==>${NC} $1"; }
success() { echo -e "${GREEN}==>${NC} $1"; }
error() { echo -e "${RED}==>${NC} $1"; exit 1; }

# Ensure USER is set (required by home-manager, may not be set in containers)
if [ -z "$USER" ]; then
    export USER=$(whoami)
fi

# Determine dotfiles directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$SCRIPT_DIR"

# Ensure ~/.dotfiles symlink exists (devpod clones to ~/dotfiles, not ~/.dotfiles)
if [ "$DOTFILES_DIR" != "$HOME/.dotfiles" ] && [ ! -e "$HOME/.dotfiles" ]; then
    ln -s "$DOTFILES_DIR" "$HOME/.dotfiles"
fi

echo ""
echo "=========================================="
echo "  Dotfiles Bootstrap (Home Manager)"
echo "=========================================="
echo ""
info "Using dotfiles from: $DOTFILES_DIR"

# Detect system
SYSTEM=""
case "$(uname -s)-$(uname -m)" in
    Darwin-arm64) SYSTEM="aarch64-darwin" ;;
    Darwin-x86_64) SYSTEM="x86_64-darwin" ;;
    Linux-x86_64) SYSTEM="x86_64-linux" ;;
    Linux-aarch64) SYSTEM="aarch64-linux" ;;
    Linux-armv7l) SYSTEM="armv7l-linux" ;;
    *) error "Unsupported system: $(uname -s)-$(uname -m)" ;;
esac
info "Detected system: $SYSTEM"

# Install Nix if not present
if ! command -v nix &> /dev/null; then
    info "Installing Nix..."
    # Use Determinate Systems installer - works as root and in containers
    curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm
    success "Nix installed"
fi

# Source Nix for this session
if [ -e "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" ]; then
    . "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
elif [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
    . "$HOME/.nix-profile/etc/profile.d/nix.sh"
fi

# Verify Nix is working
if ! command -v nix &> /dev/null; then
    error "Nix installation failed - 'nix' command not found. Try restarting your shell and running bootstrap.sh again."
fi

# Enable flakes
if ! grep -q "experimental-features" ~/.config/nix/nix.conf 2>/dev/null; then
    info "Enabling Nix flakes..."
    mkdir -p ~/.config/nix
    echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
fi

# Apply Home Manager configuration
info "Applying Home Manager configuration..."
cd "$DOTFILES_DIR"
nix run home-manager/master -- switch --flake ".#$SYSTEM" --impure -b backup
success "Home Manager configuration applied!"

# Set zsh as default shell
ZSH_PATH="$HOME/.nix-profile/bin/zsh"
if [ -x "$ZSH_PATH" ]; then
    CURRENT_SHELL=$(getent passwd "$USER" | cut -d: -f7)
    if [ "$CURRENT_SHELL" != "$ZSH_PATH" ]; then
        info "Setting zsh as default shell..."
        # Add to /etc/shells if not present
        if ! grep -q "$ZSH_PATH" /etc/shells 2>/dev/null; then
            echo "$ZSH_PATH" >> /etc/shells 2>/dev/null || true
        fi
        # Change shell (try chsh first, fall back to usermod for containers)
        if command -v chsh &> /dev/null; then
            chsh -s "$ZSH_PATH" "$USER" 2>/dev/null || usermod -s "$ZSH_PATH" "$USER" 2>/dev/null || true
        else
            usermod -s "$ZSH_PATH" "$USER" 2>/dev/null || true
        fi
        success "Default shell set to zsh"
    fi
fi

echo ""
echo "=========================================="
echo "  Bootstrap Complete!"
echo "=========================================="
echo ""
echo "Restart your terminal or run: exec zsh"
echo ""
