#!/bin/bash
# Post-install script for devcontainers
# Lightweight setup without full Home Manager (faster for ephemeral containers)
#
# For full Home Manager setup, use: ./bootstrap.sh

set -e

echo "=========================================="
echo "Installing Nix Dev Tools (Container Mode)"
echo "=========================================="

# Check if Nix is available
if ! command -v nix-env &> /dev/null; then
    echo "Nix not found. Installing..."
    curl -L https://nixos.org/nix/install | sh -s -- --no-daemon

    # Source nix
    if [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
        . "$HOME/.nix-profile/etc/profile.d/nix.sh"
    fi

    # Add to bashrc for interactive shells
    echo 'if [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then . "$HOME/.nix-profile/etc/profile.d/nix.sh"; fi' >> ~/.bashrc

    # Add to bash_profile for login shells
    echo 'if [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then . "$HOME/.nix-profile/etc/profile.d/nix.sh"; fi' >> ~/.bash_profile
    echo '[ -f ~/.bashrc ] && . ~/.bashrc' >> ~/.bash_profile

    # Add to profile for non-interactive scripts (FastAPI, etc.)
    echo 'if [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then . "$HOME/.nix-profile/etc/profile.d/nix.sh"; fi' >> ~/.profile

    # Add to zshrc/zshenv for zsh users
    echo 'if [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then . "$HOME/.nix-profile/etc/profile.d/nix.sh"; fi' >> ~/.zshenv

    # Add library paths for pip/Python compilation (all shell types)
    for rcfile in ~/.bashrc ~/.zshenv ~/.profile; do
        cat >> "$rcfile" << 'NIXLIBS'
# Nix library paths for pip/Python compilation
export PKG_CONFIG_PATH="$HOME/.nix-profile/lib/pkgconfig:$HOME/.nix-profile/share/pkgconfig:$PKG_CONFIG_PATH"
export LIBRARY_PATH="$HOME/.nix-profile/lib:$LIBRARY_PATH"
export C_INCLUDE_PATH="$HOME/.nix-profile/include:$C_INCLUDE_PATH"
export CPLUS_INCLUDE_PATH="$HOME/.nix-profile/include:$CPLUS_INCLUDE_PATH"
export LD_LIBRARY_PATH="$HOME/.nix-profile/lib:$LD_LIBRARY_PATH"
NIXLIBS
    done

    echo "Nix installed"
else
    echo "Nix already installed"
    
    # Ensure nix is sourced in all shell contexts (even if nix was pre-installed)
    if ! grep -q "nix.sh" ~/.bashrc 2>/dev/null; then
        echo 'if [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then . "$HOME/.nix-profile/etc/profile.d/nix.sh"; fi' >> ~/.bashrc
    fi
    if ! grep -q "nix.sh" ~/.bash_profile 2>/dev/null; then
        echo 'if [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then . "$HOME/.nix-profile/etc/profile.d/nix.sh"; fi' >> ~/.bash_profile
        echo '[ -f ~/.bashrc ] && . ~/.bashrc' >> ~/.bash_profile
    fi
    if ! grep -q "nix.sh" ~/.profile 2>/dev/null; then
        echo 'if [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then . "$HOME/.nix-profile/etc/profile.d/nix.sh"; fi' >> ~/.profile
    fi
    if ! grep -q "nix.sh" ~/.zshenv 2>/dev/null; then
        echo 'if [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then . "$HOME/.nix-profile/etc/profile.d/nix.sh"; fi' >> ~/.zshenv
    fi
    
    # Add library paths if not already present
    if ! grep -q "CPLUS_INCLUDE_PATH" ~/.bashrc 2>/dev/null; then
        for rcfile in ~/.bashrc ~/.zshenv ~/.profile; do
            cat >> "$rcfile" << 'NIXLIBS'
# Nix library paths for pip/Python compilation
export PKG_CONFIG_PATH="$HOME/.nix-profile/lib/pkgconfig:$HOME/.nix-profile/share/pkgconfig:$PKG_CONFIG_PATH"
export LIBRARY_PATH="$HOME/.nix-profile/lib:$LIBRARY_PATH"
export C_INCLUDE_PATH="$HOME/.nix-profile/include:$C_INCLUDE_PATH"
export CPLUS_INCLUDE_PATH="$HOME/.nix-profile/include:$CPLUS_INCLUDE_PATH"
export LD_LIBRARY_PATH="$HOME/.nix-profile/lib:$LD_LIBRARY_PATH"
NIXLIBS
        done
    fi
fi

# Ensure nixpkgs channel is configured
echo "Setting up nixpkgs channel..."
nix-channel --add https://nixos.org/channels/nixpkgs-unstable nixpkgs
nix-channel --update

# Install packages directly
echo "Installing dev tools..."
nix-env -iA \
    nixpkgs.neovim \
    nixpkgs.tmux \
    nixpkgs.ripgrep \
    nixpkgs.fd \
    nixpkgs.fzf \
    nixpkgs.lazygit \
    nixpkgs.git \
    nixpkgs.delta \
    nixpkgs.nodejs_22 \
    nixpkgs.python312 \
    nixpkgs.gcc \
    nixpkgs.gnumake \
    nixpkgs.pkg-config \
    nixpkgs.curl \
    nixpkgs.jq \
    nixpkgs.unzip \
    nixpkgs.postgresql \
    nixpkgs.libpq \
    nixpkgs.libffi \
    nixpkgs.protobuf \
    nixpkgs.cairo \
    nixpkgs.pango \
    nixpkgs.direnv

echo "Dev tools installed"

# Copy configs if dotfiles are mounted
DOTFILES_DIR="$HOME/.dotfiles"
if [ -d "$DOTFILES_DIR" ]; then
    echo "Setting up configs from dotfiles..."
    
    # Neovim
    mkdir -p ~/.config/nvim
    cp -r "$DOTFILES_DIR/nvim/"* ~/.config/nvim/
    
    # tmux
    mkdir -p ~/.config/tmux
    cp "$DOTFILES_DIR/tmux/tmux.conf" ~/.config/tmux/
    
    # tmux-sessionizer
    mkdir -p ~/.dotfiles/bin
    cp "$DOTFILES_DIR/bin/tmux-sessionizer" ~/.dotfiles/bin/
    chmod +x ~/.dotfiles/bin/tmux-sessionizer
    
    # Add to PATH
    echo 'export PATH="$HOME/.dotfiles/bin:$PATH"' >> ~/.bashrc
    
    echo "Configs copied"
fi

# Setup direnv hook
if ! grep -q "direnv hook" ~/.bashrc 2>/dev/null; then
    echo 'eval "$(direnv hook bash)"' >> ~/.bashrc
fi
if ! grep -q "direnv hook" ~/.zshrc 2>/dev/null; then
    echo 'eval "$(direnv hook zsh)"' >> ~/.zshrc 2>/dev/null || true
fi

# Verify installations
echo ""
echo "Verifying installations..."

for cmd in nvim tmux lazygit rg fd fzf; do
    if command -v "$cmd" &> /dev/null; then
        echo "  $cmd: $(command -v $cmd)"
    else
        echo "  $cmd: not found"
    fi
done

echo ""
echo "=========================================="
echo "Setup complete!"
echo "=========================================="
echo ""
echo "Usage:"
echo "  tmux             # Start tmux"
echo "  nvim .           # Open Neovim"
echo "  lazygit          # Git TUI"
echo ""
echo "In tmux:"
echo "  Ctrl+g           # Project sessionizer"
echo "  Ctrl+a           # Last session"
echo "  Ctrl+b [         # Copy mode"
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
check_command direnv

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
