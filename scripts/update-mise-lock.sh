#!/usr/bin/env bash
set -euo pipefail

command -v mise >/dev/null 2>&1 || { echo "mise is required" >&2; exit 1; }
command -v chezmoi >/dev/null 2>&1 || { echo "chezmoi is required" >&2; exit 1; }

export MISE_SYSTEM_CONFIG_DIR="$HOME/.config/mise-managed"
export MISE_CONFIG_DIR="$HOME/.config/mise"
empty_user_config=$(mktemp -d)
trap 'rm -rf "$empty_user_config"' EXIT HUP INT TERM

MISE_CONFIG_DIR="$empty_user_config" \
mise lock --global \
  --platform linux-x64,macos-arm64,windows-x64 \
  --yes
chezmoi re-add "$MISE_SYSTEM_CONFIG_DIR/mise.lock"
lock_after_refresh=$(sha256sum "$MISE_SYSTEM_CONFIG_DIR/mise.lock")
MISE_CONFIG_DIR="$empty_user_config" \
mise install
test "$lock_after_refresh" = \
  "$(sha256sum "$MISE_SYSTEM_CONFIG_DIR/mise.lock")"
