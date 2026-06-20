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
	nixpkgs#eza \
	nixpkgs#bat \
	nixpkgs#zoxide \
	nixpkgs#atuin \
	nixpkgs#zsh-fzf-tab \
	nixpkgs#lazygit \
	nixpkgs#git \
	nixpkgs#delta \
	nixpkgs#nodejs_22 \
	nixpkgs#python312 \
	nixpkgs#ruff \
	nixpkgs#lua-language-server \
	nixpkgs#gcc \
	nixpkgs#gnumake \
	nixpkgs#pkg-config \
	nixpkgs#curl \
	nixpkgs#jq \
	nixpkgs#unzip \
	nixpkgs#postgresql \
	nixpkgs#libpq \
	nixpkgs#postgres-language-server \
	nixpkgs#rainfrog \
	nixpkgs#stylua \
	nixpkgs#sqlfluff \
	nixpkgs#hadolint \
	nixpkgs#shellcheck \
	nixpkgs#yamllint \
	nixpkgs#markdownlint-cli \
	nixpkgs#libffi \
	nixpkgs#cairo \
	nixpkgs#pango \
	nixpkgs#direnv \
	nixpkgs#open-policy-agent \
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

BUN_BIN="$BUN_INSTALL/bin/bun"

# Resolve the dotfiles flake root so the arm64 path can `nix build .#bun`.
POST_INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_DIR="$(cd "$POST_INSTALL_DIR/.." && pwd)"

# Trust Nix for the native arch, never uname: under OrbStack this amd64-
# personality container reports uname -m=x86_64 even though the real VM is arm64.
nix_system="$(nix eval --impure --raw --expr 'builtins.currentSystem' 2>/dev/null || true)"

if [ "$nix_system" = "aarch64-linux" ]; then
	# Native arm64: a curl-installed or raw-prebuilt arm64 bun cannot run here --
	# the amd64 base image has no /lib/ld-linux-aarch64.so.1. Build the Nix-pinned,
	# loader-patched bun (>=1.3.14) and point ~/.bun/bin/bun at it. Running the x64
	# build under emulation instead is what wedged OMP's event loop. No AVX2 on
	# arm64, so the x64 baseline/modern handling is skipped.
	echo "Linking Nix-native arm64 bun (>=1.3.14) for OMP..."
	bun_store="$(nix build "$FLAKE_DIR#bun" --no-link --print-out-paths 2>/dev/null | tail -1)"
	if [ -n "$bun_store" ] && [ -x "$bun_store/bin/bun" ]; then
		ln -sfn "$bun_store/bin/bun" "$BUN_BIN"
	else
		echo "ERROR: failed to build Nix arm64 bun from $FLAKE_DIR#bun"
	fi
else
	# x86_64 (e.g. AWS EC2 amd64 devpods, which have AVX2). Bun's default x64 build
	# requires AVX2. On CPUs without it, bun crashes intermittently and warns "CPU
	# lacks AVX support" at startup. The official installer is idempotent by
	# version, so it will NOT swap a same-version default build for the baseline
	# variant -- fetch the baseline zip directly.
	install_bun_baseline() {
		tag="$(curl -fsSLI -o /dev/null -w '%{url_effective}' \
			https://github.com/oven-sh/bun/releases/latest 2>/dev/null | sed 's#.*/tag/##')"
		[ -n "$tag" ] || tag="bun-v$("$BUN_BIN" --version 2>/dev/null || echo "")"
		[ "$tag" = "bun-v" ] && return 1
		tmp="$(mktemp -d)"
		if curl -fsSL \
			"https://github.com/oven-sh/bun/releases/download/$tag/bun-linux-x64-baseline.zip" \
			-o "$tmp/bun.zip" && unzip -oq "$tmp/bun.zip" -d "$tmp"; then
			mkdir -p "$(dirname "$BUN_BIN")"
			install -m755 "$tmp/bun-linux-x64-baseline/bun" "$BUN_BIN"
		fi
		rm -rf "$tmp"
	}

	bun_arch=""
	if [ -x "$BUN_BIN" ]; then
		bun_arch="$("$BUN_BIN" -e 'process.stdout.write(process.platform + "-" + process.arch)' 2>/dev/null || true)"
	fi

	if [ ! -x "$BUN_BIN" ]; then
		curl -fsSL https://bun.com/install | bash
	elif [ "$bun_arch" = "linux-x64" ] && ! grep -qi avx2 /proc/cpuinfo; then
		# No AVX2: must use the baseline build. Reinstall only when the current
		# build is wrong (it warns "lacks AVX"). Never run "bun upgrade" here -- it
		# can reintroduce a default build that crashes on this CPU.
		if "$BUN_BIN" --revision 2>&1 | grep -qi "lacks AVX"; then
			echo "Installing Bun x64-baseline build for CPU without AVX2..."
			install_bun_baseline || true
		fi
	else
		"$BUN_BIN" upgrade
	fi
fi
if [ ! -x "$BUN_BIN" ]; then
	echo "ERROR: $BUN_BIN not found after Bun install/upgrade"
	exit 1
fi

set_omp_native_target() {
	omp_native_platform=""
	if [ -x "$BUN_BIN" ]; then
		omp_native_platform="$("$BUN_BIN" -e 'process.stdout.write(process.platform + "-" + process.arch)' 2>/dev/null || true)"
	fi
	case "$omp_native_platform" in
		linux-x64 | darwin-x64 | linux-arm64 | darwin-arm64)
			;;
		*)
			# Fallback when bun can't self-report: trust Nix's system, not uname
			# (which lies under OrbStack's amd64 personality).
			case "$nix_system" in
				aarch64-linux) omp_native_platform="linux-arm64" ;;
				x86_64-linux) omp_native_platform="linux-x64" ;;
				*)
					case "$(uname -s):$(uname -m)" in
						Linux:x86_64) omp_native_platform="linux-x64" ;;
						Linux:aarch64) omp_native_platform="linux-arm64" ;;
						Darwin:x86_64) omp_native_platform="darwin-x64" ;;
						Darwin:arm64) omp_native_platform="darwin-arm64" ;;
						*) return 1 ;;
					esac
					;;
			esac
			;;
	esac

	# arm64 ships a single addon variant (no AVX2 tiers); the loader probes the
	# bare "pi_natives.<platform>.node" name -- no -baseline/-modern suffix.
	case "$omp_native_platform" in
		linux-arm64 | darwin-arm64)
			omp_native_file="pi_natives.$omp_native_platform.node"
			return 0
			;;
	esac

	if [ "${PI_NATIVE_VARIANT:-}" = "modern" ] || [ "${PI_NATIVE_VARIANT:-}" = "baseline" ]; then
		omp_native_variant="$PI_NATIVE_VARIANT"
	elif [ "$omp_native_platform" = "linux-x64" ]; then
		if grep -qi avx2 /proc/cpuinfo 2>/dev/null; then
			omp_native_variant="modern"
		else
			omp_native_variant="baseline"
		fi
	elif { sysctl -n machdep.cpu.leaf7_features 2>/dev/null | grep -qi avx2; } || { sysctl -n machdep.cpu.features 2>/dev/null | grep -qi avx2; }; then
		omp_native_variant="modern"
	else
		omp_native_variant="baseline"
	fi

	omp_native_file="pi_natives.$omp_native_platform-$omp_native_variant.node"
}

ensure_omp_native_staged() {
	set_omp_native_target || return 0
	local native_dir="$BUN_INSTALL/install/global/node_modules/@oh-my-pi/pi-natives/native"
	local leaf_dir="$BUN_INSTALL/install/global/node_modules/@oh-my-pi/pi-natives-$omp_native_platform"
	local native_path="$native_dir/$omp_native_file"
	local leaf_path="$leaf_dir/$omp_native_file"

	# The loader probes @oh-my-pi/pi-natives/native, not the platform leaf package.
	# Treat the leaf package as a staging source only.

	if [ -f "$native_path" ]; then
		return 0
	fi

	if [ ! -f "$leaf_path" ]; then
		return 1
	fi

	mkdir -p "$native_dir" && rm -f "$native_path" && cp -f "$leaf_path" "$native_path"
}

install_omp_with_native() {
	set_omp_native_target || return 0
	echo "Installing OMP native addon for $omp_native_platform..."
	"$BUN_BIN" add -g "$1" @oh-my-pi/pi-natives "@oh-my-pi/pi-natives-$omp_native_platform" || return 1
	ensure_omp_native_staged || return 1
}

install_bun_global() {
	local pkg="$1"
	local bin="$2"
	if [ "$bin" = "omp" ] && set_omp_native_target; then
		install_omp_with_native "$pkg"
	elif [ ! -x "$BUN_INSTALL/bin/$bin" ]; then
		echo "Installing $pkg via bun..."
		"$BUN_BIN" add -g "$pkg"
	fi
}

install_bun_global tree-sitter-cli tree-sitter
install_bun_global basedpyright basedpyright-langserver
install_bun_global typescript-language-server typescript-language-server
install_bun_global vscode-langservers-extracted vscode-json-language-server
install_bun_global @steipete/oracle oracle
install_bun_global @openai/codex codex
install_bun_global @earendil-works/pi-coding-agent pi
install_bun_global @oh-my-pi/pi-coding-agent omp
install_bun_global @termdraw/app termdraw
install_bun_global oxlint oxlint
install_bun_global oxfmt oxfmt
install_bun_global @vtsls/language-server vtsls

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

	# Claude Code global user instructions
	cp "$DOTFILES_DIR/claude/CLAUDE.md" ~/.CLAUDE.md

	# Claude Code keybindings
	mkdir -p ~/.claude
	cp "$DOTFILES_DIR/claude/keybindings.json" ~/.claude/keybindings.json

	# Claude Code settings (hooks, default model, default mode)
	if command -v jq &>/dev/null && [ -f "$DOTFILES_DIR/claude/hooks.json" ]; then
		mkdir -p ~/.claude
		CLAUDE_SETTINGS="$HOME/.claude/settings.json"
		if [ -f "$CLAUDE_SETTINGS" ]; then
			jq --slurpfile hooks "$DOTFILES_DIR/claude/hooks.json" --slurpfile base "$DOTFILES_DIR/claude/settings.json" '. * $base[0] | .hooks = $hooks[0]' "$CLAUDE_SETTINGS" >"${CLAUDE_SETTINGS}.tmp" &&
				cat "${CLAUDE_SETTINGS}.tmp" >"$CLAUDE_SETTINGS" && rm -f "${CLAUDE_SETTINGS}.tmp"
		else
			jq -n --slurpfile hooks "$DOTFILES_DIR/claude/hooks.json" --slurpfile base "$DOTFILES_DIR/claude/settings.json" '$base[0] + {hooks: $hooks[0]}' >"$CLAUDE_SETTINGS"
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
	append_line_if_missing 'export PI_FORCE_IMAGE_PROTOCOL="kitty"' "$rcfile"
done

# Setup direnv hook for all shells
append_line_if_missing 'eval "$(direnv hook bash)"' ~/.bashrc
append_line_if_missing 'eval "$(direnv hook zsh)"' ~/.zshrc

# Modern CLI tools: shell integration (mirrors the full home.nix setup)
# zoxide (smart `z` cd) for both shells
append_line_if_missing 'eval "$(zoxide init bash)"' ~/.bashrc
append_line_if_missing 'eval "$(zoxide init zsh)"' ~/.zshrc
# atuin (Ctrl-R history search); keep the normal Up-arrow binding
append_line_if_missing 'eval "$(atuin init bash --disable-up-arrow)"' ~/.bashrc
append_line_if_missing 'eval "$(atuin init zsh --disable-up-arrow)"' ~/.zshrc
# eza aliases (modern ls); bat is available directly as `bat`
for rcfile in ~/.bashrc ~/.zshrc; do
	append_line_if_missing "alias ls='eza --icons=auto --group-directories-first'" "$rcfile"
	append_line_if_missing "alias ll='eza -l --icons=auto --git --group-directories-first'" "$rcfile"
	append_line_if_missing "alias la='eza -la --icons=auto --git --group-directories-first'" "$rcfile"
	append_line_if_missing "alias lt='eza --tree --level=2 --icons=auto --group-directories-first'" "$rcfile"
done
# Launch Claude Code at max effort (self-alias is safe; not re-expanded). /effort still switches it.
for rcfile in ~/.bashrc ~/.zshrc; do
	append_line_if_missing "alias cc='claude --effort max'" "$rcfile"
	append_line_if_missing "alias claude='claude --effort max'" "$rcfile"
done
# fzf-tab (zsh only): load after compinit, replace the completion menu with fzf.
# Stage a copy with the prebuilt binary module stripped out: its RUNPATH targets
# glibc 2.42, so on glibc 2.41 hosts it fails to load and fzf-tab nags to rebuild
# it. Without the module fzf-tab uses its working pure-zsh fallback.
FZF_TAB_NOMOD="$HOME/.local/share/fzf-tab-no-module"
if [ -d "$HOME/.nix-profile/share/fzf-tab" ]; then
	rm -rf "$FZF_TAB_NOMOD"
	mkdir -p "$(dirname "$FZF_TAB_NOMOD")"
	cp -rL "$HOME/.nix-profile/share/fzf-tab" "$FZF_TAB_NOMOD"
	chmod -R u+w "$FZF_TAB_NOMOD"
	rm -rf "$FZF_TAB_NOMOD/modules"
fi
append_line_if_missing 'autoload -Uz compinit && compinit' ~/.zshrc
append_line_if_missing "zstyle ':completion:*' menu no" ~/.zshrc
append_line_if_missing 'source "$HOME/.local/share/fzf-tab-no-module/fzf-tab.plugin.zsh"' ~/.zshrc
append_line_if_missing "zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always --icons=auto \$realpath'" ~/.zshrc

# Verify installations
echo ""
echo "Verifying installations..."

for cmd in nvim tmux lazygit rg fd fzf eza bat zoxide atuin opencode pi ruff; do
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
echo "Branch DevPod SSH:"
echo "  tailscale status       # Find the devcontainer IP"
echo "  ssh -A vscode@{ip}    # Forward your Git SSH agent"
echo "  ssh-add -l            # Verify forwarded keys inside the session"
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
check_command eza
check_command bat
check_command zoxide
check_command atuin
check_command direnv
check_command opencode
check_command pi
check_command ruff
check_command pyright-langserver

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
echo "Branch DevPod SSH:"
echo "  tailscale status       # Find the devcontainer IP"
echo "  ssh -A vscode@{ip}    # Forward your Git SSH agent"
echo "  ssh-add -l            # Verify forwarded keys inside the session"
echo ""
echo "In Neovim:"
echo "  <leader>gg       # LazyGit"
echo "  ff               # Find files"
echo "  gf               # Grep in files"
