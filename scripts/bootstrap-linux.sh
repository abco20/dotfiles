#!/usr/bin/env bash
set -euo pipefail

profile=host
desktop=false
robotics=false
dry_run=false

usage() {
  echo "usage: $0 --profile host|container [--desktop] [--robotics] [--dry-run]" >&2
}

while (($#)); do
  case "$1" in
    --profile) profile=${2:?missing profile}; shift 2 ;;
    --desktop) desktop=true; shift ;;
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
if [[ $profile == container && ($desktop == true || $robotics == true) ]]; then
  echo "container profile cannot enable desktop or robotics" >&2
  exit 2
fi

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
export MISE_SYSTEM_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/mise-managed"
source /etc/os-release
if [[ ${ID:-} != ubuntu || (${VERSION_ID:-} != 22.04 && ${VERSION_ID:-} != 24.04) ]]; then
  echo "supported Linux versions are Ubuntu 22.04 and 24.04" >&2
  exit 1
fi

run() {
  if $dry_run; then
    printf '+ '
    printf '%q ' "$@"
    printf '\n'
  else
    "$@"
  fi
}

install_apt_file() {
  local file=$1 packages=()
  mapfile -t packages < <(sed -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d' "$file")
  ((${#packages[@]})) && run sudo apt-get install -y "${packages[@]}"
}

run sudo apt-get update
install_apt_file "$root/packages/ubuntu/common.txt"
if [[ $profile == host ]]; then
  install_apt_file "$root/packages/ubuntu/host.txt"
fi

if ! command -v mise >/dev/null 2>&1; then
  run sudo apt-get install -y extrepo
  run sudo extrepo enable mise
  run sudo apt-get update
  run sudo apt-get install -y mise
fi

if $dry_run; then
  exit 0
fi

export DOTFILES_PROFILE=$profile
export DOTFILES_DESKTOP=$desktop
export DOTFILES_ROBOTICS=$robotics
export DOTFILES_ROS_DISTRO=${DOTFILES_ROS_DISTRO:-}

chezmoi_args=(init --apply --force --source "$root")
mise x aqua:twpayne/chezmoi@latest -- chezmoi "${chezmoi_args[@]}"

mise install

mise exec -- chezmoi --version
zsh -dfc 'source "$HOME/.zshrc"'

if $robotics; then
  run sudo apt-get install -y software-properties-common
  run sudo add-apt-repository -y universe
  ros_apt_source_version=$(
    curl --retry 3 --retry-all-errors -fsSL \
      https://api.github.com/repos/ros-infrastructure/ros-apt-source/releases/latest |
      awk -F'"' '/tag_name/ { print $4; exit }'
  )
  if [[ -z $ros_apt_source_version ]]; then
    echo "failed to determine ros-apt-source release version" >&2
    exit 1
  fi
  ros_apt_source_deb="/tmp/ros2-apt-source_${ros_apt_source_version}.${VERSION_CODENAME}_all.deb"
  run curl -fsSL -o "$ros_apt_source_deb" "https://github.com/ros-infrastructure/ros-apt-source/releases/download/${ros_apt_source_version}/ros2-apt-source_${ros_apt_source_version}.${VERSION_CODENAME}_all.deb"
  run sudo dpkg -i "$ros_apt_source_deb"
  run sudo apt-get update
  install_apt_file "$root/packages/ubuntu/robotics.txt"
  ros_distro=${DOTFILES_ROS_DISTRO:-}
  if [[ -z $ros_distro ]]; then
    [[ $VERSION_ID == 22.04 ]] && ros_distro=humble || ros_distro=jazzy
  fi
  run sudo apt-get install -y "ros-$ros_distro-desktop" "ros-$ros_distro-rmw-cyclonedds-cpp" ros-dev-tools
  if ! [[ -e /etc/ros/rosdep/sources.list.d/20-default.list ]]; then
    run sudo rosdep init
  fi
  run rosdep update
fi

echo "bootstrap completed"
