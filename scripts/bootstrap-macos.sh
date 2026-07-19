#!/usr/bin/env bash
set -Eeuo pipefail

trap '
  status=$?
  printf \
    "::error file=%s,line=%s::command failed with exit %d: %s\n" \
    "${BASH_SOURCE[0]}" \
    "$LINENO" \
    "$status" \
    "$BASH_COMMAND" \
    >&2
  exit "$status"
' ERR

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

mise_version=${MISE_VERSION:-v2026.7.7}
mise_bin="$HOME/.local/bin/mise"

if [[ ! -x $mise_bin ]] ||
   [[ $("$mise_bin" --version) != *"${mise_version#v}"* ]]; then
  echo "Installing mise $mise_version"
  curl --retry 3 --retry-all-errors -fsSL https://mise.run |
    MISE_VERSION="$mise_version" \
    MISE_INSTALL_PATH="$mise_bin" \
    sh
fi

export PATH="$HOME/.local/bin:$PATH"
hash -r

"$mise_bin" --version

export DOTFILES_PROFILE=$profile DOTFILES_DESKTOP=$desktop DOTFILES_ROBOTICS=false DOTFILES_ROS_DISTRO=
chezmoi_args=(init --apply --force --source "$root")
echo "Applying chezmoi configuration"
"$mise_bin" x aqua:twpayne/chezmoi@2.71.0 -- \
  chezmoi "${chezmoi_args[@]}"
echo "Checking managed mise configuration"
"$mise_bin" config ls
echo "Installing mise tools"
"$mise_bin" install --jobs=1
echo "Checking installed chezmoi"
"$mise_bin" exec aqua:twpayne/chezmoi@2.71.0 -- \
  chezmoi --version
echo "Checking zsh configuration"
zsh -dfc 'source "$HOME/.zshrc"'
