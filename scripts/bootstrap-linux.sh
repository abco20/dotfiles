#!/usr/bin/env bash
set -euo pipefail

profile=host
desktop=false
personal_apps=false
robotics=false
dry_run=false

usage() {
  echo "usage: $0 --profile host|container [--desktop] [--personal-apps] [--robotics] [--dry-run]" >&2
}

while (($#)); do
  case $1 in
    --profile) profile=${2:?missing profile}; shift 2 ;;
    --desktop) desktop=true; shift ;;
    --personal-apps) personal_apps=true; shift ;;
    --robotics) robotics=true; shift ;;
    --dry-run) dry_run=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage; exit 2 ;;
  esac
done

if [[ $profile != host && $profile != container ]]; then
  echo "unsupported profile: $profile" >&2
  exit 2
fi
if [[ $personal_apps == true && $desktop != true ]]; then
  echo "--personal-apps requires --desktop" >&2
  exit 2
fi
if [[ $profile == container &&
      ($desktop == true || $personal_apps == true || $robotics == true) ]]; then
  echo "container profile cannot enable desktop, personal apps, or robotics" >&2
  exit 2
fi

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
export MISE_SYSTEM_CONFIG_DIR="$HOME/.config/mise-managed"
export MISE_CONFIG_DIR="$HOME/.config/mise"
source /etc/os-release
if [[ ${ID:-} != ubuntu ||
      (${VERSION_ID:-} != 22.04 && ${VERSION_ID:-} != 24.04) ]]; then
  echo "supported Linux versions are Ubuntu 22.04 and 24.04" >&2
  exit 1
fi

source "$root/scripts/lib/ubuntu/common.sh"
source "$root/scripts/lib/ubuntu/repositories.sh"
source "$root/scripts/lib/ubuntu/desktop.sh"
source "$root/scripts/lib/ubuntu/robotics.sh"

run sudo apt-get update
install_apt_file "$root/packages/ubuntu/common.txt"
[[ $profile == host ]] && install_apt_file "$root/packages/ubuntu/host.txt"
[[ $desktop == true ]] && install_desktop_apps "$personal_apps"

if ! command -v mise >/dev/null 2>&1; then
  run sudo apt-get install -y extrepo
  run sudo extrepo enable mise
  run sudo apt-get update
  run sudo apt-get install -y mise
fi

$dry_run && exit 0

export DOTFILES_PROFILE=$profile
export DOTFILES_DESKTOP=$desktop
export DOTFILES_ROBOTICS=$robotics
export DOTFILES_ROS_DISTRO=${DOTFILES_ROS_DISTRO:-}
mise x aqua:twpayne/chezmoi@latest -- \
  chezmoi init --apply --force --source "$root"
mise install
mise exec -- chezmoi --version
zsh -dfc 'source "$HOME/.zshrc"'

[[ $robotics == true ]] && install_robotics

echo "bootstrap completed"
if [[ $desktop == true ]]; then
  echo "Log out and log back in to use Docker without sudo."
fi
