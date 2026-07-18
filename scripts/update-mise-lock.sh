#!/usr/bin/env bash
set -euo pipefail

command -v mise >/dev/null 2>&1 || { echo "mise is required" >&2; exit 1; }
command -v chezmoi >/dev/null 2>&1 || { echo "chezmoi is required" >&2; exit 1; }

MISE_LOCKFILE=true mise lock --global --platform linux-x64,macos-arm64,windows-x64 --yes
chezmoi re-add "$HOME/.config/mise/mise.lock"
MISE_LOCKFILE=true mise install --locked
