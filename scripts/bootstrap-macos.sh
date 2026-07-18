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
echo "Installing Homebrew common bundle"
run brew bundle --file "$root/packages/macos/Brewfile.common"
if [[ $profile == host ]]; then
  echo "Installing Homebrew host bundle"
  run brew bundle \
    --file "$root/packages/macos/Brewfile.host"
fi
if [[ $desktop == true ]]; then
  echo "Installing Homebrew desktop bundle"
  run brew bundle \
    --file "$root/packages/macos/Brewfile.desktop"
fi
if [[ $desktop == true &&
      $skip_manual_desktop == false ]]; then
  echo "Installing Homebrew manual desktop bundle"
  run brew bundle \
    --file "$root/packages/macos/Brewfile.desktop-manual"
fi
if [[ $personal_apps == true ]]; then
  echo "Installing Homebrew personal bundle"
  run brew bundle \
    --file "$root/packages/macos/Brewfile.personal"
fi
$dry_run && exit 0

if ! brew list --formula mise >/dev/null 2>&1; then
  echo "mise was not installed by Homebrew" >&2
  exit 1
fi

export PATH="$(brew --prefix)/bin:$PATH"
hash -r

command -v mise >/dev/null 2>&1 || {
  echo "mise is not available after Homebrew installation" >&2
  exit 1
}

export DOTFILES_PROFILE=$profile DOTFILES_DESKTOP=$desktop DOTFILES_ROBOTICS=false DOTFILES_ROS_DISTRO=
chezmoi_args=(init --apply --force --source "$root")
echo "Applying chezmoi configuration"
mise x aqua:twpayne/chezmoi@latest -- chezmoi "${chezmoi_args[@]}"
echo "Installing mise tools"
mise install
echo "Checking zsh configuration"
zsh -dfc 'source "$HOME/.zshrc"'
