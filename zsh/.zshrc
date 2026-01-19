# Auto-start Zellij (skip if in IDE)
# Do this BEFORE entering nix-shell so Zellij panes run inside nix-shell
IS_IN_IDE=0
if [[ "$TERM_PROGRAM" == "vscode" || -n "$INTELLIJ_ENVIRONMENT_READER" ]]; then
  IS_IN_IDE=1
fi

if [[ -z "$VSCODE_PID" && -z "$VSCODE_INJECTION" ]] && command -v zellij &>/dev/null && [[ -z "$ZELLIJ" ]]; then
    # Try to attach to the most recent NON-EXITED session, or create a new one
    if zellij list-sessions | grep -q " (current)"; then
        # Attach to the current session if one exists
        zellij attach -c "$(zellij list-sessions | grep " (current)" | awk '{print $1}')"
    else
        # Create a new session if no active ones exist
        zellij
    fi
    # Exit terminal when Zellij closes
    exit
fi

# Auto-enter nix-shell for global development environment
# This ensures all dev tools are always available
# Skip if SKIP_NIX_SHELL is set (e.g., for scripts that need to run quickly)
if [[ -z "$IN_NIX_SHELL" ]] && [[ -z "$SKIP_NIX_SHELL" ]] && command -v nix-shell &>/dev/null; then
  # Enter nix-shell from dotfiles directory
  DOTFILES_DIR="${HOME}/.dotfiles"
  if [[ -f "${DOTFILES_DIR}/shell.nix" ]]; then
    exec nix-shell "${DOTFILES_DIR}/shell.nix"
  fi
fi

# Starship prompt
eval "$(starship init zsh)"

# Add dotfiles bin to PATH
export PATH="$HOME/.dotfiles/bin:$PATH"

# Aliases
alias python=python3
alias google-chrome="/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome"
alias pip=pip3
alias ll="ls -alG"
alias zs="zellij-sessionizer"  # Quick project switcher

# pipx
export PATH="$PATH:/Users/cfraser/.local/bin"

# Completions
autoload -Uz compinit
compinit

# Bun completions
[ -s "/Users/cfraser/.bun/_bun" ] && source "/Users/cfraser/.bun/_bun"

# Bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
if [ -e "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" ]; then . "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"; fi
