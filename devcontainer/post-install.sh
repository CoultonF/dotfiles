#!/bin/bash
# Post-install script for devcontainers
# Add this to your post-create-command.sh or run manually

set -e

echo "=========================================="
echo "Installing Nix Dev Tools..."
echo "=========================================="

# Check if Nix is available
if ! command -v nix-env &> /dev/null; then
    echo "Nix not found. Installing..."
    curl -L https://nixos.org/nix/install | sh -s -- --no-daemon

    # Source nix
    if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
        . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
    fi
    if [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
        . "$HOME/.nix-profile/etc/profile.d/nix.sh"
    fi

    # Add to bashrc for future sessions
    echo 'if [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then . "$HOME/.nix-profile/etc/profile.d/nix.sh"; fi' >> ~/.bashrc

    echo "✅ Nix installed"
else
    echo "✅ Nix already installed"
fi

# Install packages from config.nix
if [ -f /root/.config/nixpkgs/config.nix ]; then
    echo "Installing dev tools from config.nix..."
    nix-env -iA nixpkgs.devTools
    echo "✅ Dev tools installed"
else
    echo "⚠️ No config.nix found at /root/.config/nixpkgs/config.nix"
    echo "   Mount your dotfiles nix config or install packages manually:"
    echo "   nix-env -iA nixpkgs.neovim nixpkgs.opencode nixpkgs.lazygit nixpkgs.ripgrep"
fi

# Verify installations
echo ""
echo "Verifying installations..."

check_command() {
    if command -v "$1" &> /dev/null; then
        echo "✅ $1: $(command -v $1)"
    else
        echo "❌ $1: not found"
    fi
}

check_command nvim
check_command opencode
check_command lazygit
check_command rg
check_command fd
check_command fzf

echo ""
echo "=========================================="
echo "Setup complete!"
echo "=========================================="
echo ""
echo "Usage:"
echo "  nvim .           # Open Neovim"
echo "  opencode         # Start OpenCode AI assistant"
echo "  lazygit          # Git TUI"
echo ""
echo "In Neovim:"
echo "  <leader>oa       # Ask OpenCode"
echo "  <leader>gg       # LazyGit"
echo "  ff               # Find files"
echo "  gf               # Grep in files"
