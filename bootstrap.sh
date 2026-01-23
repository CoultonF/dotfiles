#!/bin/bash
# Bootstrap script for dotfiles with Home Manager
# Installs Nix (single-user mode) and applies Home Manager configuration

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
    info "Installing Nix (single-user mode)..."
    curl -L https://nixos.org/nix/install | sh -s -- --no-daemon --yes
    success "Nix installed"
fi

# Source Nix for this session
if [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
    . "$HOME/.nix-profile/etc/profile.d/nix.sh"
fi

# Verify Nix is working
if ! command -v nix &> /dev/null; then
    error "Nix installation failed - 'nix' command not found. Try restarting your shell and running bootstrap.sh again."
fi

# Ensure Nix is in PATH for all zsh shells (system-wide)
# This ensures SSH commands have Nix available
NIX_ZSHENV_SNIPPET='
# Nix single-user
if [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
    . "$HOME/.nix-profile/etc/profile.d/nix.sh"
fi'

for zshenv_path in /etc/zshenv /etc/zsh/zshenv; do
    if [ -e "$zshenv_path" ] || [ -d "$(dirname "$zshenv_path")" ]; then
        if ! grep -q "nix-profile" "$zshenv_path" 2>/dev/null; then
            info "Adding Nix to $zshenv_path..."
            echo "$NIX_ZSHENV_SNIPPET" | sudo tee -a "$zshenv_path" > /dev/null
        fi
    fi
done

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

# Set Nix zsh as default shell
NIX_ZSH="$HOME/.nix-profile/bin/zsh"
if [ -x "$NIX_ZSH" ]; then
    info "Setting Nix zsh as default shell..."
    
    # Add to /etc/shells
    if ! grep -q "$NIX_ZSH" /etc/shells 2>/dev/null; then
        echo "$NIX_ZSH" | sudo tee -a /etc/shells > /dev/null
    fi
    
    # Change default shell
    sudo chsh -s "$NIX_ZSH" "$USER" 2>/dev/null || chsh -s "$NIX_ZSH" 2>/dev/null || true
    
    # Fallback: update /etc/passwd directly (containers)
    if [ "$(id -u)" = "0" ]; then
        sed -i "s|$USER:.*:/bin/bash|$USER:x:$(id -u):$(id -g)::/home/$USER:$NIX_ZSH|" /etc/passwd 2>/dev/null || true
    fi
    
    success "Default shell set to $NIX_ZSH"
fi

echo ""
echo "=========================================="
echo "  Bootstrap Complete!"
echo "=========================================="
echo ""
echo "Restart your terminal or run: exec zsh"
echo ""
