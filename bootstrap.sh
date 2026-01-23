#!/bin/bash
# Bootstrap script for dotfiles with Home Manager
# This is the only script you need to run on a fresh machine

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}==>${NC} $1"; }
success() { echo -e "${GREEN}==>${NC} $1"; }
warn() { echo -e "${YELLOW}==>${NC} $1"; }
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
    *) error "Unsupported system: $(uname -s)-$(uname -m)" ;;
esac
info "Detected system: $SYSTEM"

# Step 1: Install Nix if not present
if ! command -v nix &> /dev/null; then
    info "Installing Nix..."
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS: Use the standard installer
        curl -L https://nixos.org/nix/install | sh -s -- --daemon
    else
        # Linux containers: Create nixbld group and configure for single-user
        if ! getent group nixbld >/dev/null 2>&1; then
            groupadd -r nixbld 2>/dev/null || true
        fi
        
        # Install Nix
        curl -L https://nixos.org/nix/install | sh -s -- --no-daemon
        
        # Configure Nix to not require build users (single-user mode)
        mkdir -p ~/.config/nix
        if ! grep -q "build-users-group" ~/.config/nix/nix.conf 2>/dev/null; then
            echo "build-users-group = " >> ~/.config/nix/nix.conf
        fi
    fi
    
    # Source Nix for this session
    if [ -e "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" ]; then
        . "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
    elif [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
        . "$HOME/.nix-profile/etc/profile.d/nix.sh"
    fi
    
    success "Nix installed"
else
    success "Nix already installed"
fi

# Step 2: Enable flakes if not already enabled
if ! grep -q "experimental-features" ~/.config/nix/nix.conf 2>/dev/null; then
    info "Enabling Nix flakes..."
    mkdir -p ~/.config/nix
    echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
    success "Flakes enabled"
else
    success "Flakes already enabled"
fi

# Step 3: Run Home Manager
info "Applying Home Manager configuration..."
cd "$DOTFILES_DIR"

# Use nix run to execute home-manager without installing it globally first
# --impure allows reading $USER and $HOME environment variables
nix run home-manager/master -- switch --flake ".#$SYSTEM" --impure -b backup

success "Home Manager configuration applied!"

# Step 4: Set zsh as default shell (if not already)
if [ "$SHELL" != "/bin/zsh" ] && [ -x /bin/zsh ]; then
    info "Setting zsh as default shell..."
    if command -v chsh &>/dev/null; then
        chsh -s /bin/zsh "$USER" 2>/dev/null || sudo chsh -s /bin/zsh "$USER" 2>/dev/null || true
    fi
    # Also update /etc/passwd directly if we're root (common in containers)
    if [ "$(id -u)" = "0" ] && [ -w /etc/passwd ]; then
        sed -i "s|^root:.*:/bin/bash|root:x:0:0:root:/root:/bin/zsh|" /etc/passwd 2>/dev/null || true
    fi
fi

# Step 5: Add bash fallback (source nix profile in .bashrc)
if ! grep -q "nix-daemon.sh" ~/.bashrc 2>/dev/null; then
    info "Adding nix profile to .bashrc as fallback..."
    cat >> ~/.bashrc << 'BASHRC'

# Nix profile (added by dotfiles bootstrap)
if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
  . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
fi
BASHRC
fi

echo ""
echo "=========================================="
echo "  Bootstrap Complete!"
echo "=========================================="
echo ""
echo "Your dotfiles are now managed by Home Manager."
echo ""
echo "Common commands:"
echo "  home-manager switch --flake ~/.dotfiles   # Apply changes"
echo "  home-manager generations                  # List generations"
echo "  home-manager packages                     # List installed packages"
echo ""
echo "Restart your terminal or run: exec zsh"
echo ""
