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
error() {
	echo -e "${RED}==>${NC} $1"
	exit 1
}

append_line_if_missing() {
	local line="$1"
	local file="$2"

	if [ -e "$file" ]; then
		if grep -qxF "$line" "$file" 2>/dev/null; then
			return 0
		fi
		if [ ! -w "$file" ]; then
			info "Skipping $file (not writable)"
			return 0
		fi
	elif ! touch "$file" 2>/dev/null; then
		info "Skipping $file (cannot create)"
		return 0
	fi

	echo "$line" >>"$file" || info "Skipping $file (append failed)"
}

# Ensure USER is set (required by home-manager, may not be set in containers)
if [ -z "$USER" ]; then
	export USER=$(whoami)
fi

# Determine dotfiles directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES_DIR="$SCRIPT_DIR"
export PI_CONFIG_DIR="dotfiles/omp"
export PI_CODING_AGENT_DIR="$HOME/$PI_CONFIG_DIR/agent"

# Ensure OMP's agent directory exists in dotfiles while preserving an existing credential DB.
mkdir -p "$DOTFILES_DIR/omp/agent"
if [ -f "$HOME/.omp/agent/agent.db" ] && [ ! -e "$DOTFILES_DIR/omp/agent/agent.db" ]; then
	ln -s "$HOME/.omp/agent/agent.db" "$DOTFILES_DIR/omp/agent/agent.db"
fi
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
if ! command -v nix &>/dev/null; then
	if [ -e "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" ]; then
		. "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
	elif [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
		. "$HOME/.nix-profile/etc/profile.d/nix.sh"
	fi
fi

# Install Nix only if it's truly not present (not just missing from PATH)
if ! command -v nix &>/dev/null && [ ! -x "/nix/var/nix/profiles/default/bin/nix" ]; then
	info "Installing Nix..."
	if [ "$(uname -s)" = "Linux" ] && ! pidof systemd >/dev/null 2>&1; then
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
if ! command -v nix &>/dev/null && [ -x "/nix/var/nix/profiles/default/bin/nix" ]; then
	export PATH="/nix/var/nix/profiles/default/bin:$HOME/.nix-profile/bin:$PATH"
fi

# Verify Nix is working
if ! command -v nix &>/dev/null; then
	error "Nix not found. Install Nix first (e.g. devcontainer nix feature or: curl -sSf -L https://install.determinate.systems/nix | sh -s -- install)"
fi

info "Using $(nix --version)"

# Ensure Nix daemon is running (containers without systemd need manual start)
if [ "$(uname -s)" = "Linux" ] && ! pidof systemd >/dev/null 2>&1; then
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
	if ! command -v locale-gen &>/dev/null; then
		sudo apt-get update -qq && sudo apt-get install -y -qq locales >/dev/null 2>&1
	fi
	if command -v locale-gen &>/dev/null; then
		sudo sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen 2>/dev/null || true
		sudo locale-gen en_US.UTF-8 2>/dev/null || true
	fi
fi

# Fix missing nixbld group in containers (e.g. devcontainer nix feature)
if ! getent group nixbld >/dev/null 2>&1; then
	info "Creating nixbld group for Nix builds..."
	sudo groupadd -r nixbld 2>/dev/null || true
	for i in $(seq 1 8); do
		sudo useradd -r -g nixbld -G nixbld -d /var/empty -s /usr/sbin/nologin "nixbld$i" 2>/dev/null || true
	done
	# Restart daemon to pick up the new group
	if [ "$(uname -s)" = "Linux" ] && ! pidof systemd >/dev/null 2>&1; then
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
	if ! grep -q "experimental-features" /etc/nix/nix.conf 2>/dev/null &&
		! grep -q "experimental-features" ~/.config/nix/nix.conf 2>/dev/null; then
		info "Enabling Nix flakes..."
		mkdir -p ~/.config/nix
		echo "experimental-features = nix-command flakes" >>~/.config/nix/nix.conf
	fi
fi
# Apply Home Manager configuration
info "Applying Home Manager configuration..."
cd "$DOTFILES_DIR"
nix run home-manager/master -- switch --flake ".#$SYSTEM" --impure -b backup
success "Home Manager configuration applied!"
# Home Manager owns ~/.zshenv, which is often a read-only Nix store symlink.
for rcfile in ~/.bashrc ~/.bash_profile ~/.profile; do
	append_line_if_missing 'export PI_CONFIG_DIR="dotfiles/omp"' "$rcfile"
	append_line_if_missing 'export PI_CODING_AGENT_DIR="$HOME/$PI_CONFIG_DIR/agent"' "$rcfile"
	append_line_if_missing 'export PI_OAUTH_CALLBACK_HOST=0.0.0.0' "$rcfile"
done

# Apply Claude Code hooks
# ~/.claude/settings.json may be a virtiofs bind-mount from the Mac host (OrbStack).
# mv/rename fail on mount points (EBUSY), so we write in-place via tee instead.
if command -v jq &>/dev/null && [ -f "$DOTFILES_DIR/claude/hooks.json" ]; then
	info "Applying Claude Code hooks..."
	mkdir -p ~/.claude
	CLAUDE_SETTINGS="$HOME/.claude/settings.json"
	if [ -f "$CLAUDE_SETTINGS" ]; then
		jq --slurpfile hooks "$DOTFILES_DIR/claude/hooks.json" '.hooks = $hooks[0]' "$CLAUDE_SETTINGS" | tee "$CLAUDE_SETTINGS" >/dev/null \
			&& success "Claude Code hooks applied" \
			|| warn "Could not write $CLAUDE_SETTINGS (virtiofs mount missing host file?). On your Mac run: echo '{}' > ~/.claude/settings.json"
	else
		jq -n --slurpfile hooks "$DOTFILES_DIR/claude/hooks.json" '{hooks: $hooks[0]}' | tee "$CLAUDE_SETTINGS" >/dev/null \
			&& success "Claude Code hooks applied" \
			|| warn "Could not write $CLAUDE_SETTINGS (virtiofs mount missing host file?). On your Mac run: echo '{}' > ~/.claude/settings.json"
	fi
fi

# Set zsh as default shell.
# Use a system-owned zsh path for login shells. Nix profile paths are generation
# symlinks and can disappear after profile changes, which leaves new terminals
# unable to start (for example: /home/vscode/.nix-profile/bin/zsh).
SHELL_FIX_COMMAND=""
case "$(uname -s)" in
Darwin)
	ZSH_PATH="/bin/zsh"
	SHELL_FIX_COMMAND="sudo chsh -s /bin/zsh $USER"
	;;
Linux)
	ZSH_PATH="/usr/bin/zsh"
	SHELL_FIX_COMMAND="sudo usermod -s /usr/bin/zsh $USER"
	;;
*) ZSH_PATH="" ;;
esac

if [ "$(uname -s)" = "Linux" ] && [ -n "$ZSH_PATH" ] && [ ! -x "$ZSH_PATH" ] && command -v apt-get &>/dev/null; then
	info "Installing zsh system-wide..."
	sudo apt-get update -qq && sudo apt-get install -y -qq zsh >/dev/null || true
fi

if [ -n "$ZSH_PATH" ] && [ -x "$ZSH_PATH" ]; then
	CURRENT_SHELL="$(getent passwd "$USER" 2>/dev/null | cut -d: -f7 || true)"
	if [ -z "$CURRENT_SHELL" ]; then
		CURRENT_SHELL="${SHELL:-}"
	fi
	if [ "$CURRENT_SHELL" != "$ZSH_PATH" ]; then
		info "Setting zsh as default shell..."
		if ! grep -q "^$ZSH_PATH$" /etc/shells 2>/dev/null; then
			echo "$ZSH_PATH" | sudo tee -a /etc/shells >/dev/null || true
		fi
		SHELL_CHANGED=0
		if command -v chsh &>/dev/null; then
			if sudo chsh -s "$ZSH_PATH" "$USER" 2>/dev/null || { command -v usermod &>/dev/null && sudo usermod -s "$ZSH_PATH" "$USER" 2>/dev/null; }; then
				SHELL_CHANGED=1
			fi
		elif command -v usermod &>/dev/null && sudo usermod -s "$ZSH_PATH" "$USER" 2>/dev/null; then
			SHELL_CHANGED=1
		fi
		if [ "$SHELL_CHANGED" -eq 1 ]; then
			success "Default shell set to $ZSH_PATH"
		else
			info "Could not change default shell automatically; run: $SHELL_FIX_COMMAND"
		fi
	fi
else
	info "System zsh not found; leaving default shell unchanged"
fi

echo ""
echo "=========================================="
echo "  Bootstrap Complete!"
echo "=========================================="
echo ""
echo "Restart your terminal or run: exec zsh"
echo ""
