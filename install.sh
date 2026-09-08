#!/usr/bin/env bash
# Entry point for local installs and devpod.
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

exec "$SCRIPT_DIR/bootstrap.sh" "$@"
