#!/usr/bin/env bash
set -euo pipefail

profile=host
desktop=false
personal_apps=false
skip_manual_desktop=false
dry_run=false
while (($#)); do
  case "$1" in
    --profile) profile=${2:?missing profile}; shift 2 ;;
    --desktop) desktop=true; shift ;;
    --personal-apps) personal_apps=true; shift ;;
    --skip-manual-desktop) skip_manual_desktop=true; shift ;;
    --dry-run) dry_run=true; shift ;;
    *) echo "usage: $0 --profile host|container [--desktop] [--personal-apps] [--skip-manual-desktop] [--dry-run]" >&2; exit 2 ;;
  esac
done
[[ $profile == host || $profile == container ]] || { echo "unsupported profile: $profile" >&2; exit 2; }
[[ $personal_apps == false || $desktop == true ]] || { echo "--personal-apps requires --desktop" >&2; exit 2; }
[[ $skip_manual_desktop == false || $desktop == true ]] || { echo "--skip-manual-desktop requires --desktop" >&2; exit 2; }
[[ $profile == host || ($desktop == false && $personal_apps == false) ]] || { echo "container profile cannot enable desktop or personal apps" >&2; exit 2; }

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
export MISE_SYSTEM_CONFIG_DIR="$HOME/.config/mise-managed"
export MISE_CONFIG_DIR="$HOME/.config/mise"
run() { if $dry_run; then printf '+ %q ' "$@"; printf '\n'; else "$@"; fi; }

command -v brew >/dev/null 2>&1 || { echo "Homebrew must be installed first" >&2; exit 1; }
run brew bundle --file "$root/packages/macos/Brewfile.common"
[[ $profile == host ]] && run brew bundle --file "$root/packages/macos/Brewfile.host"
[[ $desktop == true ]] && run brew bundle --file "$root/packages/macos/Brewfile.desktop"
[[ $desktop == true && $skip_manual_desktop == false ]] && \
  run brew bundle --file "$root/packages/macos/Brewfile.desktop-manual"
[[ $personal_apps == true ]] && run brew bundle --file "$root/packages/macos/Brewfile.personal"
$dry_run && exit 0

command -v mise >/dev/null 2>&1 || {
  echo "mise was not installed by Homebrew" >&2
  exit 1
}
case $(command -v mise) in
  "$(brew --prefix)"/*) ;;
  *) echo "mise is not installed under the Homebrew prefix" >&2; exit 1 ;;
esac

export DOTFILES_PROFILE=$profile DOTFILES_DESKTOP=$desktop DOTFILES_ROBOTICS=false DOTFILES_ROS_DISTRO=
chezmoi_args=(init --apply --force --source "$root")
mise x aqua:twpayne/chezmoi@latest -- chezmoi "${chezmoi_args[@]}"
mise install
zsh -dfc 'source "$HOME/.zshrc"'
