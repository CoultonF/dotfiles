#!/usr/bin/env bash
# Wrapper for devpod compatibility - calls the actual bootstrap script
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES_DIR="$SCRIPT_DIR"
export PI_CONFIG_DIR="dotfiles/omp"
export PI_CODING_AGENT_DIR="$HOME/$PI_CONFIG_DIR/agent"

exec "$SCRIPT_DIR/bootstrap.sh" "$@"
