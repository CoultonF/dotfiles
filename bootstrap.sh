#!/bin/bash
# Bootstrap script for dotfiles with Home Manager
# If Nix is already installed (e.g. via devcontainer feature), skips installation
# Otherwise installs via Determinate Systems installer

# Suppress locale warnings from system bash when en_US.UTF-8 isn't generated yet
# (fixed later in this script by running locale-gen)
if ! locale -a 2>/dev/null | grep -qi "en_US.utf8"; then
    unset LC_ALL
fi

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

# Source Nix into PATH if not already available
# Check common locations: PATH, Determinate Nix default profile, single-user profile
if ! command -v nix &> /dev/null; then
    if [ -e "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" ]; then
        . "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
    elif [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
        . "$HOME/.nix-profile/etc/profile.d/nix.sh"
    fi
fi

# Install Nix only if it's truly not present (not just missing from PATH)
if ! command -v nix &> /dev/null && [ ! -x "/nix/var/nix/profiles/default/bin/nix" ]; then
    info "Installing Nix..."
    if [ "$(uname -s)" = "Linux" ] && ! pidof systemd > /dev/null 2>&1; then
        curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install linux --no-confirm --init none --extra-conf "sandbox = false"
        # Start the Nix daemon manually since there's no init system
        sudo /nix/var/nix/profiles/default/bin/nix-daemon &
        # Wait for daemon to be ready
        for i in $(seq 1 30); do
            if nix store ping 2>/dev/null; then break; fi
            sleep 1
        done
    else
        curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm
    fi
    success "Nix installed"

    # Source after fresh install
    if [ -e "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" ]; then
        . "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
    elif [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
        . "$HOME/.nix-profile/etc/profile.d/nix.sh"
    fi
else
    success "Nix already installed, skipping installation"
fi

# Last resort: force PATH if nix binary exists but sourcing didn't work
if ! command -v nix &> /dev/null && [ -x "/nix/var/nix/profiles/default/bin/nix" ]; then
    export PATH="/nix/var/nix/profiles/default/bin:$HOME/.nix-profile/bin:$PATH"
fi

# Verify Nix is working
if ! command -v nix &> /dev/null; then
    error "Nix not found. Install Nix first (e.g. devcontainer nix feature or: curl -sSf -L https://install.determinate.systems/nix | sh -s -- install)"
fi

info "Using $(nix --version)"

# Ensure Nix daemon is running (containers without systemd need manual start)
if [ "$(uname -s)" = "Linux" ] && ! pidof systemd > /dev/null 2>&1; then
    if ! nix store ping 2>/dev/null; then
        info "Starting Nix daemon..."
        sudo /nix/var/nix/profiles/default/bin/nix-daemon &
        for i in $(seq 1 30); do
            if nix store ping 2>/dev/null; then break; fi
            sleep 1
        done
        if ! nix store ping 2>/dev/null; then
            error "Nix daemon failed to start"
        fi
        success "Nix daemon started"
    fi
fi

# Generate en_US.UTF-8 locale for system programs (e.g. /bin/bash uses system
# glibc which can't read Nix's locale archive due to version mismatch)
if [ "$(uname -s)" = "Linux" ] && ! locale -a 2>/dev/null | grep -qi "en_US.utf8"; then
    info "Generating en_US.UTF-8 locale..."
    if command -v locale-gen &> /dev/null; then
        sudo sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen 2>/dev/null || true
        sudo locale-gen en_US.UTF-8 2>/dev/null || true
    elif [ -f /etc/locale.gen ]; then
        sudo apt-get update -qq && sudo apt-get install -y -qq locales > /dev/null 2>&1
        sudo sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
        sudo locale-gen en_US.UTF-8 2>/dev/null || true
    fi
fi

# Fix missing nixbld group in containers (e.g. devcontainer nix feature)
if ! getent group nixbld > /dev/null 2>&1; then
    info "Creating nixbld group for Nix builds..."
    sudo groupadd -r nixbld 2>/dev/null || true
    for i in $(seq 1 8); do
        sudo useradd -r -g nixbld -G nixbld -d /var/empty -s /usr/sbin/nologin "nixbld$i" 2>/dev/null || true
    done
    # Restart daemon to pick up the new group
    if [ "$(uname -s)" = "Linux" ] && ! pidof systemd > /dev/null 2>&1; then
        sudo pkill -f nix-daemon 2>/dev/null || true
        sleep 1
        sudo /nix/var/nix/profiles/default/bin/nix-daemon &
        for i in $(seq 1 30); do
            if nix store ping 2>/dev/null; then break; fi
            sleep 1
        done
    fi
fi

# Enable flakes if not already configured (devcontainer feature may have set this)
if ! nix show-config 2>/dev/null | grep -q "flakes"; then
    if ! grep -q "experimental-features" /etc/nix/nix.conf 2>/dev/null && \
       ! grep -q "experimental-features" ~/.config/nix/nix.conf 2>/dev/null; then
        info "Enabling Nix flakes..."
        mkdir -p ~/.config/nix
        echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
    fi
fi

# Apply Home Manager configuration
info "Applying Home Manager configuration..."
cd "$DOTFILES_DIR"
nix run home-manager/master -- switch --flake ".#$SYSTEM" --impure -b backup
success "Home Manager configuration applied!"

# Apply Claude Code hooks
if command -v jq &> /dev/null && [ -f "$DOTFILES_DIR/claude/hooks.json" ]; then
    info "Applying Claude Code hooks..."
    mkdir -p ~/.claude
    CLAUDE_SETTINGS="$HOME/.claude/settings.json"
    if [ -f "$CLAUDE_SETTINGS" ]; then
        jq --slurpfile hooks "$DOTFILES_DIR/claude/hooks.json" '.hooks = $hooks[0]' "$CLAUDE_SETTINGS" > "${CLAUDE_SETTINGS}.tmp" \
            && cat "${CLAUDE_SETTINGS}.tmp" > "$CLAUDE_SETTINGS" && rm -f "${CLAUDE_SETTINGS}.tmp"
    else
        jq -n --slurpfile hooks "$DOTFILES_DIR/claude/hooks.json" '{hooks: $hooks[0]}' > "$CLAUDE_SETTINGS"
    fi
    success "Claude Code hooks applied"
fi

# Set zsh as default shell
# Install zsh system-wide so SSH sessions can find it without nix profile resolution
if ! command -v /usr/bin/zsh &> /dev/null; then
    info "Installing zsh system-wide..."
    sudo apt-get update -qq && sudo apt-get install -y -qq zsh > /dev/null 2>&1 || true
fi
ZSH_PATH=$(command -v zsh 2>/dev/null || echo "/usr/bin/zsh")
if [ -x "$ZSH_PATH" ]; then
    CURRENT_SHELL=$(getent passwd "$USER" | cut -d: -f7)
    if [ "$CURRENT_SHELL" != "$ZSH_PATH" ]; then
        info "Setting zsh as default shell..."
        if ! grep -q "$ZSH_PATH" /etc/shells 2>/dev/null; then
            echo "$ZSH_PATH" | sudo tee -a /etc/shells > /dev/null 2>/dev/null || true
        fi
        if command -v chsh &> /dev/null; then
            sudo chsh -s "$ZSH_PATH" "$USER" 2>/dev/null || sudo usermod -s "$ZSH_PATH" "$USER" 2>/dev/null || true
        else
            sudo usermod -s "$ZSH_PATH" "$USER" 2>/dev/null || true
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
