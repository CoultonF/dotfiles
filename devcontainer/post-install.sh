#!/bin/bash
# Post-install script for devcontainers
# Lightweight setup without full Home Manager (faster for ephemeral containers)
#
# For full Home Manager setup, use: ./bootstrap.sh

set -e

echo "=========================================="
echo "Installing Nix Dev Tools (Container Mode)"
echo "=========================================="

# Source Nix into PATH if not already available
if ! command -v nix &> /dev/null; then
    if [ -e "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" ]; then
        . "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
    elif [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
        . "$HOME/.nix-profile/etc/profile.d/nix.sh"
    fi
fi

# Last resort: force PATH if nix binary exists but sourcing didn't work
if ! command -v nix &> /dev/null && [ -x "/nix/var/nix/profiles/default/bin/nix" ]; then
    export PATH="/nix/var/nix/profiles/default/bin:$HOME/.nix-profile/bin:$PATH"
fi

# Verify Nix is available
if ! command -v nix &> /dev/null; then
    echo "ERROR: Nix not found. Ensure the devcontainer nix feature is enabled."
    exit 1
fi

echo "Using $(nix --version)"

# Enable flakes if not already configured
if ! nix show-config 2>/dev/null | grep -q "flakes"; then
    if ! grep -q "experimental-features" /etc/nix/nix.conf 2>/dev/null && \
       ! grep -q "experimental-features" ~/.config/nix/nix.conf 2>/dev/null; then
        echo "Enabling Nix flakes..."
        mkdir -p ~/.config/nix
        echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
    fi
fi

# Install packages using nix profile (flakes-native, works with Determinate Nix)
echo "Installing dev tools..."
nix profile install \
    nixpkgs#neovim \
    nixpkgs#tmux \
    nixpkgs#ripgrep \
    nixpkgs#fd \
    nixpkgs#fzf \
    nixpkgs#lazygit \
    nixpkgs#git \
    nixpkgs#delta \
    nixpkgs#nodejs_22 \
    nixpkgs#python312 \
    nixpkgs#gcc \
    nixpkgs#gnumake \
    nixpkgs#pkg-config \
    nixpkgs#curl \
    nixpkgs#jq \
    nixpkgs#unzip \
    nixpkgs#postgresql \
    nixpkgs#libpq \
    nixpkgs#libffi \
    nixpkgs#protobuf \
    nixpkgs#cairo \
    nixpkgs#pango \
    nixpkgs#direnv

echo "Dev tools installed"

# Ensure Nix is sourced in shell profiles
for rcfile in ~/.bashrc ~/.bash_profile ~/.profile ~/.zshenv; do
    if [ ! -f "$rcfile" ] || ! grep -q "nix-daemon.sh\|nix.sh" "$rcfile" 2>/dev/null; then
        cat >> "$rcfile" << 'NIXSOURCE'
# Source Nix
if [ -e "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" ]; then
    . "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
elif [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
    . "$HOME/.nix-profile/etc/profile.d/nix.sh"
fi
NIXSOURCE
    fi
done

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
    
    # Claude Code hooks
    if command -v jq &> /dev/null && [ -f "$DOTFILES_DIR/claude/hooks.json" ]; then
        mkdir -p ~/.claude
        CLAUDE_SETTINGS="$HOME/.claude/settings.json"
        if [ -f "$CLAUDE_SETTINGS" ]; then
            jq --slurpfile hooks "$DOTFILES_DIR/claude/hooks.json" '.hooks = $hooks[0]' "$CLAUDE_SETTINGS" > "${CLAUDE_SETTINGS}.tmp" \
                && mv "${CLAUDE_SETTINGS}.tmp" "$CLAUDE_SETTINGS"
        else
            jq -n --slurpfile hooks "$DOTFILES_DIR/claude/hooks.json" '{hooks: $hooks[0]}' > "$CLAUDE_SETTINGS"
        fi
    fi

    echo "Configs copied"
fi

# Setup direnv hook for all shells
if ! grep -q "direnv hook" ~/.bashrc 2>/dev/null; then
    echo 'eval "$(direnv hook bash)"' >> ~/.bashrc
fi
touch ~/.zshrc
if ! grep -q "direnv hook" ~/.zshrc 2>/dev/null; then
    echo 'eval "$(direnv hook zsh)"' >> ~/.zshrc
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
