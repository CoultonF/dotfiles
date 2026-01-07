#!/bin/bash
# Dotfiles Installation Script
# Run this on a new machine to set up the development environment

set -e

# Determine dotfiles directory - use script location if not in ~/.dotfiles
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -d "$HOME/.dotfiles" ] && [ -f "$HOME/.dotfiles/install.sh" ]; then
    DOTFILES_DIR="$HOME/.dotfiles"
elif [ -f "$SCRIPT_DIR/install.sh" ]; then
    DOTFILES_DIR="$SCRIPT_DIR"
else
    echo "Could not determine dotfiles directory"
    exit 1
fi

CONFIG_DIR="$HOME/.config"
DOCKER_CONFIG_DIR="$HOME/.config-docker"
DOCKER_LOCAL_DIR="$HOME/.local-docker"

echo "=========================================="
echo "  Dotfiles Installation"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

success() { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}!${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; }

echo "Using dotfiles from: $DOTFILES_DIR"

echo ""
echo "Creating directories..."

# Create config directories
mkdir -p "$CONFIG_DIR"
mkdir -p "$DOCKER_CONFIG_DIR/nvim"
mkdir -p "$DOCKER_CONFIG_DIR/nix"
mkdir -p "$DOCKER_LOCAL_DIR/share/nvim"
success "Created config directories"

echo ""
echo "Setting up Ghostty..."

# Ghostty config (local Mac)
mkdir -p "$CONFIG_DIR/ghostty"
if [ -L "$CONFIG_DIR/ghostty/config" ] || [ -f "$CONFIG_DIR/ghostty/config" ]; then
    rm -f "$CONFIG_DIR/ghostty/config"
fi
ln -sf "$DOTFILES_DIR/ghostty/config" "$CONFIG_DIR/ghostty/config"
success "Linked Ghostty config"

echo ""
echo "Setting up Neovim (for devcontainer)..."

# Copy nvim config to docker config directory (this gets mounted into containers)
cp -r "$DOTFILES_DIR/nvim/"* "$DOCKER_CONFIG_DIR/nvim/"
success "Copied Neovim config to $DOCKER_CONFIG_DIR/nvim"

# Also set up local nvim config
mkdir -p "$CONFIG_DIR/nvim"
if [ -d "$CONFIG_DIR/nvim" ] && [ ! -L "$CONFIG_DIR/nvim" ]; then
    # Check if directory is a mount point (common in containers)
    if mountpoint -q "$CONFIG_DIR/nvim" 2>/dev/null; then
        # It's a mount point, just clear contents and copy
        rm -rf "$CONFIG_DIR/nvim/"* 2>/dev/null || true
    elif [ "$(ls -A $CONFIG_DIR/nvim 2>/dev/null)" ]; then
        # Has content, try to backup (may fail if busy)
        if mv "$CONFIG_DIR/nvim" "$CONFIG_DIR/nvim.backup" 2>/dev/null; then
            warn "Backed up existing nvim config to $CONFIG_DIR/nvim.backup"
            mkdir -p "$CONFIG_DIR/nvim"
        else
            # Backup failed (device busy), just clear contents
            warn "Could not backup nvim config (directory busy), replacing contents"
            rm -rf "$CONFIG_DIR/nvim/"* 2>/dev/null || true
        fi
    fi
fi
cp -r "$DOTFILES_DIR/nvim/"* "$CONFIG_DIR/nvim/"
success "Copied Neovim config to $CONFIG_DIR/nvim (local)"

echo ""
echo "Setting up Nix config..."

# Nix config for devcontainer
cp "$DOTFILES_DIR/nix/config.nix" "$DOCKER_CONFIG_DIR/nix/config.nix"
success "Copied Nix config to $DOCKER_CONFIG_DIR/nix"

# Also set up local nix config
mkdir -p "$CONFIG_DIR/nixpkgs"
ln -sf "$DOTFILES_DIR/nix/config.nix" "$CONFIG_DIR/nixpkgs/config.nix"
success "Linked Nix config locally"

echo ""
echo "Checking dependencies..."

# Check for Ghostty
if command -v ghostty &> /dev/null || [ -d "/Applications/Ghostty.app" ]; then
    success "Ghostty is installed"
else
    warn "Ghostty not found. Install from: https://ghostty.org"
fi

# Check for Homebrew (macOS)
if [[ "$OSTYPE" == "darwin"* ]]; then
    if command -v brew &> /dev/null; then
        success "Homebrew is installed"
    else
        warn "Homebrew not found. Install from: https://brew.sh"
    fi
fi

# Check for Docker
if command -v docker &> /dev/null; then
    success "Docker is installed"
else
    warn "Docker not found. Required for devcontainers."
fi

echo ""
echo "=========================================="
echo "  Installation Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo ""
echo "1. Install Ghostty (if not installed):"
echo "   brew install --cask ghostty"
echo ""
echo "2. Install a Nerd Font (for icons):"
echo "   brew install --cask font-jetbrains-mono-nerd-font"
echo ""
echo "3. For devcontainers, add these mounts to your devcontainer.json:"
echo '   "mounts": ['
echo '     "source=${localEnv:HOME}/.config-docker/nvim,target=/root/.config/nvim,type=bind",'
echo '     "source=${localEnv:HOME}/.local-docker/share/nvim,target=/root/.local/share/nvim,type=bind",'
echo '     "source=${localEnv:HOME}/.config-docker/nix,target=/root/.config/nixpkgs,type=bind"'
echo '   ]'
echo ""
echo "4. Add Nix to your Dockerfile.dev:"
echo '   RUN curl -L https://nixos.org/nix/install | sh -s -- --no-daemon'
echo '   ENV PATH="/root/.nix-profile/bin:$PATH"'
echo ""
echo "5. Install Nix packages in container:"
echo "   nix-env -iA nixpkgs.devTools"
echo ""
echo "See README.md for full documentation."
