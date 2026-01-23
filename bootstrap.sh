#!/bin/bash
# Bootstrap script for dotfiles with Home Manager
# Nix will be installed automatically if not present (idempotent)

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

# Install Nix if not present (idempotent)
if ! command -v nix &> /dev/null; then
    info "Nix not found, installing..."
    
    # Clean up any stale backup files from previous failed installs
    rm -f /etc/bash.bashrc.backup-before-nix /etc/bashrc.backup-before-nix 2>/dev/null || true
    rm -f /etc/profile.d/nix.sh.backup-before-nix 2>/dev/null || true
    
    # Install Nix in daemon mode (multi-user)
    # --yes skips confirmation prompts
    curl -L https://nixos.org/nix/install | sh -s -- --daemon --yes
    
    # Source Nix for this session
    if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
        . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
    fi
    
    success "Nix installed"
else
    # Source Nix if available but not in PATH (e.g., volume mount scenario)
    if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
        . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
    fi
    success "Nix is available"
fi

# Ensure /etc/profile.d/nix.sh exists for login shells
# This runs regardless of whether Nix was just installed or already available (volume mount)
if [ -d /etc/profile.d ] && [ ! -e /etc/profile.d/nix.sh ]; then
    info "Creating /etc/profile.d/nix.sh..."
    sudo tee /etc/profile.d/nix.sh > /dev/null << 'EOF'
# Nix package manager
if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
    . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
fi
EOF
    sudo chmod +x /etc/profile.d/nix.sh
fi

# Enable flakes if not already enabled
if ! grep -q "experimental-features" ~/.config/nix/nix.conf 2>/dev/null; then
    info "Enabling Nix flakes..."
    mkdir -p ~/.config/nix
    echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
    success "Flakes enabled"
else
    success "Flakes already enabled"
fi

# Apply Home Manager configuration
info "Applying Home Manager configuration..."
cd "$DOTFILES_DIR"

# Use nix run to execute home-manager without installing it globally first
# --impure allows reading $USER and $HOME environment variables
nix run home-manager/master -- switch --flake ".#$SYSTEM" --impure -b backup

success "Home Manager configuration applied!"

# Set zsh as default shell (if not already)
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
