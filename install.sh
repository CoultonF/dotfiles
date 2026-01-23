#!/usr/bin/env bash
# Wrapper for devpod compatibility - calls the actual bootstrap script
exec "$(dirname "$0")/bootstrap.sh" "$@"
