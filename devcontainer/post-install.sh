#!/bin/bash
# Post-install script for devcontainers
# Lightweight setup without full Home Manager (faster for ephemeral containers)
#
# For full Home Manager setup, use: ./bootstrap.sh

set -e

append_line_if_missing() {
	local line="$1"
	local file="$2"

	if [ -e "$file" ]; then
		if grep -qxF "$line" "$file" 2>/dev/null; then
			return 0
		fi
		if [ ! -w "$file" ]; then
			echo "Skipping $file (not writable)"
			return 0
		fi
	elif ! touch "$file" 2>/dev/null; then
		echo "Skipping $file (cannot create)"
		return 0
	fi

	echo "$line" >>"$file" || echo "Skipping $file (append failed)"
}

echo "=========================================="
echo "Installing Nix Dev Tools (Container Mode)"
echo "=========================================="

# Source Nix into PATH if not already available
if ! command -v nix &>/dev/null; then
	if [ -e "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" ]; then
		. "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
	elif [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
		. "$HOME/.nix-profile/etc/profile.d/nix.sh"
	fi
fi

# Last resort: force PATH if nix binary exists but sourcing didn't work
if ! command -v nix &>/dev/null && [ -x "/nix/var/nix/profiles/default/bin/nix" ]; then
	export PATH="/nix/var/nix/profiles/default/bin:$HOME/.nix-profile/bin:$PATH"
fi

# Verify Nix is available
if ! command -v nix &>/dev/null; then
	echo "ERROR: Nix not found. Ensure the devcontainer nix feature is enabled."
	exit 1
fi

echo "Using $(nix --version)"

# Enable flakes if not already configured
if ! nix show-config 2>/dev/null | grep -q "flakes"; then
	if ! grep -q "experimental-features" /etc/nix/nix.conf 2>/dev/null &&
		! grep -q "experimental-features" ~/.config/nix/nix.conf 2>/dev/null; then
		echo "Enabling Nix flakes..."
		mkdir -p ~/.config/nix
		echo "experimental-features = nix-command flakes" >>~/.config/nix/nix.conf
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
	nixpkgs#ruff \
	nixpkgs#gcc \
	nixpkgs#gnumake \
	nixpkgs#pkg-config \
	nixpkgs#curl \
	nixpkgs#jq \
	nixpkgs#unzip \
	nixpkgs#postgresql \
	nixpkgs#libpq \
	nixpkgs#libffi \
	nixpkgs#cairo \
	nixpkgs#pango \
	nixpkgs#direnv \
	nixpkgs#opencode \
	nixpkgs#bun \
	nixpkgs#chromium \
	nixpkgs#bubblewrap

echo "Dev tools installed"

# Install bun-managed CLIs from the npm registry
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$HOME/.nix-profile/bin:/nix/var/nix/profiles/default/bin:$PATH"
mkdir -p "$BUN_INSTALL/bin"
append_line_if_missing 'export PATH="$HOME/.bun/bin:$PATH"' ~/.bashrc

# npm global installs must use a writable prefix; Nix's node prefix is immutable.
export NPM_CONFIG_PREFIX="$HOME/.npm-global"
export PATH="$NPM_CONFIG_PREFIX/bin:$PATH"
mkdir -p "$NPM_CONFIG_PREFIX/bin"
printf 'prefix=%s\n' "$NPM_CONFIG_PREFIX" >"$HOME/.npmrc"
append_line_if_missing 'export NPM_CONFIG_PREFIX="$HOME/.npm-global"' ~/.bashrc
append_line_if_missing 'export PATH="$HOME/.npm-global/bin:$PATH"' ~/.bashrc

install_bun_global() {
	local pkg="$1"
	local bin="$2"
	if [ ! -x "$BUN_INSTALL/bin/$bin" ]; then
		echo "Installing $pkg via bun..."
		bun add -g "$pkg"
	fi
}

install_bun_global tree-sitter-cli tree-sitter
install_bun_global typescript-language-server typescript-language-server
install_bun_global vscode-langservers-extracted vscode-json-language-server
install_bun_global @steipete/oracle oracle
install_bun_global @openai/codex codex
install_bun_global @earendil-works/pi-coding-agent pi
install_bun_global @oh-my-pi/pi-coding-agent omp

# Nixpkgs bun lags; upgrade to latest to meet tool version requirements
bun upgrade

CHROMIUM_BIN="$(command -v chromium 2>/dev/null || true)"
if [ -n "$CHROMIUM_BIN" ]; then
	echo "Using Chromium for Puppeteer: $CHROMIUM_BIN"
	export PUPPETEER_EXECUTABLE_PATH="$CHROMIUM_BIN"
else
	echo "WARNING: chromium not found; Puppeteer may fall back to its downloaded browser"
fi

# Ensure Nix is sourced in shell profiles
for rcfile in ~/.bashrc ~/.bash_profile ~/.profile ~/.zshenv; do
	if [ -e "$rcfile" ] && [ ! -w "$rcfile" ]; then
		echo "Skipping $rcfile (not writable)"
		continue
	fi
	if [ ! -f "$rcfile" ] || ! grep -q "nix-daemon.sh\|nix.sh" "$rcfile" 2>/dev/null; then
		if ! touch "$rcfile" 2>/dev/null; then
			echo "Skipping $rcfile (cannot create)"
			continue
		fi
		cat >>"$rcfile" <<'NIXSOURCE'
# Source Nix
if [ -e "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" ]; then
    . "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
elif [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
    . "$HOME/.nix-profile/etc/profile.d/nix.sh"
fi
NIXSOURCE
	fi
done

# Copy configs from this checkout, regardless of where the devcontainer mounted it.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
if [ -d "$DOTFILES_DIR" ]; then
	echo "Setting up configs from dotfiles..."

	# Neovim
	mkdir -p ~/.config/nvim
	cp -r "$DOTFILES_DIR/nvim/"* ~/.config/nvim/

	# tmux
	mkdir -p ~/.config/tmux
	cp "$DOTFILES_DIR/tmux/tmux.conf" ~/.config/tmux/

	# OpenCode
	mkdir -p ~/.config/opencode
	cp -r "$DOTFILES_DIR/opencode/"* ~/.config/opencode/

	# Pi
	mkdir -p ~/.pi/agent ~/.pi/agent/skills ~/.pi/agent/extensions
	cp "$DOTFILES_DIR/pi/settings.json" ~/.pi/agent/settings.json
	cp "$DOTFILES_DIR/pi/APPEND_SYSTEM.md" ~/.pi/agent/APPEND_SYSTEM.md
	cp "$DOTFILES_DIR/pi/keybindings.json" ~/.pi/agent/keybindings.json
	cp "$DOTFILES_DIR/pi/mcp.json" ~/.pi/agent/mcp.json
	cp -r "$DOTFILES_DIR/pi/skills/." ~/.pi/agent/skills/ 2>/dev/null || true
	cp -r "$DOTFILES_DIR/pi/extensions/." ~/.pi/agent/extensions/ 2>/dev/null || true

	# tmux-sessionizer
	mkdir -p ~/.dotfiles/bin
	cp "$DOTFILES_DIR/bin/tmux-sessionizer" ~/.dotfiles/bin/
	chmod +x ~/.dotfiles/bin/tmux-sessionizer

	# Add to PATH
	append_line_if_missing 'export PATH="$HOME/.dotfiles/bin:$PATH"' ~/.bashrc

	# Claude Code hooks
	if command -v jq &>/dev/null && [ -f "$DOTFILES_DIR/claude/hooks.json" ]; then
		mkdir -p ~/.claude
		CLAUDE_SETTINGS="$HOME/.claude/settings.json"
		if [ -f "$CLAUDE_SETTINGS" ]; then
			jq --slurpfile hooks "$DOTFILES_DIR/claude/hooks.json" '.hooks = $hooks[0]' "$CLAUDE_SETTINGS" >"${CLAUDE_SETTINGS}.tmp" &&
				cat "${CLAUDE_SETTINGS}.tmp" >"$CLAUDE_SETTINGS" && rm -f "${CLAUDE_SETTINGS}.tmp"
		else
			jq -n --slurpfile hooks "$DOTFILES_DIR/claude/hooks.json" '{hooks: $hooks[0]}' >"$CLAUDE_SETTINGS"
		fi
	fi

	echo "Configs copied"
fi

# Disable Claude Code fallbacks in OpenCode
for rcfile in ~/.bashrc ~/.bash_profile ~/.profile ~/.zshenv ~/.zshrc; do
	append_line_if_missing 'export OPENCODE_DISABLE_CLAUDE_CODE=1' "$rcfile"
	append_line_if_missing 'export OPENCODE_DISABLE_CLAUDE_CODE_PROMPT=1' "$rcfile"
	append_line_if_missing 'export OPENCODE_DISABLE_CLAUDE_CODE_SKILLS=1' "$rcfile"
	append_line_if_missing 'export PI_CONFIG_DIR="dotfiles/omp"' "$rcfile"
	append_line_if_missing 'export PI_CODING_AGENT_DIR="$HOME/$PI_CONFIG_DIR/agent"' "$rcfile"
	append_line_if_missing 'export PI_OAUTH_CALLBACK_HOST=0.0.0.0' "$rcfile"
	append_line_if_missing 'export PUPPETEER_EXECUTABLE_PATH="$HOME/.nix-profile/bin/chromium"' "$rcfile"
done

# Setup direnv hook for all shells
append_line_if_missing 'eval "$(direnv hook bash)"' ~/.bashrc
append_line_if_missing 'eval "$(direnv hook zsh)"' ~/.zshrc

# Verify installations
echo ""
echo "Verifying installations..."

for cmd in nvim tmux lazygit rg fd fzf opencode pi ruff; do
	if command -v "$cmd" &>/dev/null; then
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
echo "  opencode         # OpenCode TUI"
echo "  pi               # Pi coding agent"
echo ""
echo "In tmux:"
echo "  Ctrl+g           # Project sessionizer"
echo "  Ctrl+a           # Last session"
echo "  Ctrl+b [         # Copy mode"
echo ""
echo "Verifying installations..."

check_command() {
	if command -v "$1" &>/dev/null; then
		echo "✅ $1: $(command -v $1)"
	else
		echo "❌ $1: not found"
	fi
}

check_command nvim
check_command lazygit
check_command rg
check_command fd
check_command fzf
check_command direnv
check_command opencode
check_command pi
check_command ruff

echo ""
echo "=========================================="
echo "Setup complete!"
echo "=========================================="
echo ""
echo "Usage:"
echo "  nvim .           # Open Neovim"
echo "  lazygit          # Git TUI"
echo "  opencode         # OpenCode TUI"
echo "  pi               # Pi coding agent"
echo ""
echo "In Neovim:"
echo "  <leader>gg       # LazyGit"
echo "  ff               # Find files"
echo "  gf               # Grep in files"
