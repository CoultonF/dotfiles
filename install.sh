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
DOCKER_NIX_DIR="$HOME/.nix-docker"

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
mkdir -p "$DOCKER_NIX_DIR"
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
echo "Setting up Zellij..."

# Zellij config (both local and container)
mkdir -p "$CONFIG_DIR/zellij"
if [ -L "$CONFIG_DIR/zellij/config.kdl" ] || [ -f "$CONFIG_DIR/zellij/config.kdl" ]; then
    rm -f "$CONFIG_DIR/zellij/config.kdl"
fi
ln -sf "$DOTFILES_DIR/zellij/config.kdl" "$CONFIG_DIR/zellij/config.kdl"
success "Linked Zellij config"

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
echo "Setting up OpenCode..."

# OpenCode config
mkdir -p "$CONFIG_DIR/opencode"
if [ -f "$DOTFILES_DIR/opencode/opencode.json" ]; then
    ln -sf "$DOTFILES_DIR/opencode/opencode.json" "$CONFIG_DIR/opencode/opencode.json"
    success "Linked OpenCode config"
fi

echo ""
echo "Setting up Nix config..."

# Nix config for devcontainer - remove old symlink if exists
if [ -L "$DOCKER_CONFIG_DIR/nix/config.nix" ] || [ -f "$DOCKER_CONFIG_DIR/nix/config.nix" ]; then
    rm -f "$DOCKER_CONFIG_DIR/nix/config.nix"
fi
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

# Check for Nix (required for nix-shell environment)
if command -v nix-shell &> /dev/null; then
    success "Nix is installed"
else
    warn "Nix not found. Install from: https://nixos.org/download.html"
    warn "Without Nix, the global nix-shell environment won't work"
fi

echo ""
echo "Setting up shell environment..."

# Set up zsh with nix-shell auto-entry
if [ -f "$DOTFILES_DIR/zsh/.zshrc" ]; then
    # Backup existing .zshrc if it exists and is not a symlink
    if [ -f "$HOME/.zshrc" ] && [ ! -L "$HOME/.zshrc" ]; then
        mv "$HOME/.zshrc" "$HOME/.zshrc.backup"
        warn "Backed up existing .zshrc to $HOME/.zshrc.backup"
    fi

    # Remove old symlink/file if exists
    rm -f "$HOME/.zshrc"

    # Symlink the dotfiles .zshrc
    ln -sf "$DOTFILES_DIR/zsh/.zshrc" "$HOME/.zshrc"
    success "Linked .zshrc with nix-shell auto-entry"
else
    warn ".zshrc template not found in dotfiles"
fi

# Function to configure a shell rc file (for bash)
configure_shell_rc() {
    local rc_file="$1"
    local rc_name="$2"

    if ! grep -q 'export EDITOR=nvim' "$rc_file" 2>/dev/null; then
        echo 'export EDITOR=nvim' >> "$rc_file"
        success "Added 'export EDITOR=nvim' to $rc_name"
    else
        success "EDITOR=nvim already set in $rc_name"
    fi

    # Add Xvfb setup for headless clipboard (containers without X11)
    if ! grep -q 'DISPLAY=:99' "$rc_file" 2>/dev/null; then
        cat >> "$rc_file" << 'XVFB_EOF'

# Headless clipboard support (for containers without X11)
if [ -z "$DISPLAY" ] && command -v Xvfb &> /dev/null; then
    if ! pgrep -x Xvfb > /dev/null; then
        Xvfb :99 -screen 0 1024x768x24 > /dev/null 2>&1 &
    fi
    export DISPLAY=:99
fi
XVFB_EOF
        success "Added Xvfb/DISPLAY setup to $rc_name"
    else
        success "Xvfb/DISPLAY already configured in $rc_name"
    fi
}

# Configure .bashrc if it exists (containers might use bash)
if [ -f "$HOME/.bashrc" ]; then
    configure_shell_rc "$HOME/.bashrc" ".bashrc"
fi

echo ""
echo "Detecting environment..."

# Check if running in a container (and not on macOS)
IN_CONTAINER=false
IS_MACOS=false

# Detect macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
    IS_MACOS=true
    success "macOS environment detected"
fi

# Debug output
echo "DEBUG: Checking container environment..."
echo "DEBUG: OSTYPE=$OSTYPE"
echo "DEBUG: /.dockerenv exists: $([ -f /.dockerenv ] && echo 'yes' || echo 'no')"
echo "DEBUG: /proc/1/cgroup check: $(grep -q docker /proc/1/cgroup 2>/dev/null && echo 'docker found' || echo 'docker not found')"

# DevPod/container detection - check multiple signals
if [ -f /.dockerenv ] || \
   grep -q docker /proc/1/cgroup 2>/dev/null || \
   grep -q kubepods /proc/1/cgroup 2>/dev/null || \
   [ -n "$DEVPOD_WORKSPACE_ID" ] || \
   [ -n "$CODESPACES" ] || \
   [ "$REMOTE_CONTAINERS" = "true" ]; then
    IN_CONTAINER=true
    success "Container environment detected"
fi

echo ""
echo "=========================================="
echo "  Installing Dev Tools"
echo "=========================================="
echo ""

# Install Nix package manager
if ! command -v nix-env &> /dev/null; then
    echo "Installing Nix package manager..."

    if [ "$IS_MACOS" = true ]; then
        # Use daemon installer on macOS (recommended)
        echo "Using Nix daemon installer for macOS..."
        sh <(curl -L https://nixos.org/nix/install)
    else
        # Use single-user installer in containers
        echo "Using Nix single-user installer for container..."
        curl -L https://nixos.org/nix/install | sh -s -- --no-daemon
    fi

    # Source nix for this session
    if [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
        . "$HOME/.nix-profile/etc/profile.d/nix.sh"
    elif [ -e "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" ]; then
        . "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
    fi

    # Add to shell configs for future sessions
    if [ "$IS_MACOS" = true ]; then
        NIX_SOURCE='if [ -e "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" ]; then . "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"; fi'
    else
        NIX_SOURCE='if [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then . "$HOME/.nix-profile/etc/profile.d/nix.sh"; fi'
    fi

    if [ -f "$HOME/.bashrc" ]; then
        if ! grep -q 'nix-profile/etc/profile.d/nix' "$HOME/.bashrc" 2>/dev/null && ! grep -q 'nix-daemon.sh' "$HOME/.bashrc" 2>/dev/null; then
            echo "$NIX_SOURCE" >> "$HOME/.bashrc"
        fi
    fi

    if [ -f "$HOME/.zshrc" ]; then
        if ! grep -q 'nix-profile/etc/profile.d/nix' "$HOME/.zshrc" 2>/dev/null && ! grep -q 'nix-daemon.sh' "$HOME/.zshrc" 2>/dev/null; then
            echo "$NIX_SOURCE" >> "$HOME/.zshrc"
        fi
    fi

    success "Nix installed"
else
    success "Nix already installed"
fi

# Install packages from config.nix
if [ -f "$CONFIG_DIR/nixpkgs/config.nix" ]; then
    echo "Installing dev tools from config.nix..."
    nix-env -iA nixpkgs.devTools
    success "Dev tools installed"

    echo ""
    echo "Verifying installations..."
    for cmd in nvim opencode lazygit rg fd fzf zellij; do
        if command -v "$cmd" &> /dev/null; then
            success "$cmd: $(command -v $cmd)"
        else
            warn "$cmd: not found"
        fi
    done
else
    warn "No config.nix found, skipping package installation"
fi

# Container-specific setup
if [ "$IN_CONTAINER" = true ]; then
    echo ""
    echo "Container-specific configuration..."

    # Fix locale warnings by setting locale environment variables
    echo "Configuring locale..."

    # Add to shell configs to override any locale sent by SSH client
    for rc_file in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [ -f "$rc_file" ]; then
            if ! grep -q 'export LC_ALL=C.UTF-8' "$rc_file" 2>/dev/null; then
                cat >> "$rc_file" << 'LOCALE_EOF'

# Locale settings (prevent SSH client locale warnings)
export LC_ALL=C.UTF-8
export LANG=C.UTF-8
LOCALE_EOF
            fi
        fi
    done
    success "Locale configured (using C.UTF-8)"
    echo ""
fi

echo ""
echo "=========================================="
echo "  Installation Complete!"
echo "=========================================="
echo ""

if [ "$IN_CONTAINER" = true ]; then
    echo "Container setup complete! You can now use:"
    echo ""
    echo "  zellij           # Start Zellij (terminal multiplexer with vim mode)"
    echo "  nvim .           # Open Neovim"
    echo "  opencode         # Start OpenCode AI assistant"
    echo "  lazygit          # Git TUI"
    echo ""
    echo "In Zellij:"
    echo "  Ctrl+a [         # Enter scroll/copy mode (vim keybindings)"
    echo "  j/k              # Navigate (in scroll mode)"
    echo "  Space            # Start selection"
    echo "  y                # Copy selection"
    echo ""
    echo "In Neovim:"
    echo "  <leader>oa       # Ask OpenCode"
    echo "  <leader>gg       # LazyGit"
    echo "  ff               # Find files"
    echo "  gf               # Grep in files"
    echo ""
fi

if [ "$IS_MACOS" = true ]; then
    echo "macOS next steps:"
    echo ""
    echo "1. RESTART your terminal to load Nix in PATH"
    echo "   All dev tools (nvim, lazygit, zellij, etc.) will then be available globally"
    echo ""
    echo "2. Install Ghostty (if not installed):"
    echo "   brew install --cask ghostty"
    echo ""
    echo "3. Install a Nerd Font (for icons):"
    echo "   brew install --cask font-jetbrains-mono-nerd-font"
    echo ""
fi

echo "See README.md for full documentation."
