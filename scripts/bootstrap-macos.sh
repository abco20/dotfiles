#!/usr/bin/env bash
set -euo pipefail

profile=host
desktop=false
dry_run=false
while (($#)); do
  case "$1" in
    --profile) profile=${2:?missing profile}; shift 2 ;;
    --desktop) desktop=true; shift ;;
    --dry-run) dry_run=true; shift ;;
    *) echo "usage: $0 --profile host|container [--desktop] [--dry-run]" >&2; exit 2 ;;
  esac
done
[[ $profile == host || $profile == container ]] || { echo "unsupported profile: $profile" >&2; exit 2; }
[[ $profile == host || $desktop == false ]] || { echo "container profile cannot enable desktop" >&2; exit 2; }

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
run() { if $dry_run; then printf '+ %q ' "$@"; printf '\n'; else "$@"; fi; }

command -v brew >/dev/null 2>&1 || { echo "Homebrew must be installed first" >&2; exit 1; }
run brew bundle --file "$root/packages/macos/Brewfile.common"
[[ $profile == host ]] && run brew bundle --file "$root/packages/macos/Brewfile.host"
[[ $desktop == true ]] && run brew bundle --file "$root/packages/macos/Brewfile.desktop"
$dry_run && exit 0

export DOTFILES_PROFILE=$profile DOTFILES_DESKTOP=$desktop DOTFILES_ROBOTICS=false DOTFILES_ROS_DISTRO=
chezmoi_args=(init --apply --source "$root")
if [[ $profile == host ]]; then
  chezmoi_args+=(--less-interactive)
fi
mise x aqua:twpayne/chezmoi@latest -- chezmoi "${chezmoi_args[@]}"
MISE_LOCKFILE=true mise install --locked
zsh -dfc 'source "$HOME/.zshrc"'
