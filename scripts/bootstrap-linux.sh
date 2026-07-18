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
export MISE_SYSTEM_CONFIG_DIR="$HOME/.config/mise-managed"
export MISE_CONFIG_DIR="$HOME/.config/mise"
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

install_wezterm() (
  set -euo pipefail

  local keyring=/usr/share/keyrings/wezterm-fury.gpg
  local source=/etc/apt/sources.list.d/wezterm.list
  local work

  if $dry_run; then
    echo '+ install WezTerm from apt.fury.io'
    return
  fi

  work=$(mktemp -d)
  trap 'rm -rf "$work"' EXIT HUP INT TERM

  if [[ ! -f $keyring ]]; then
    curl --retry 3 --retry-all-errors -fsSL \
      https://apt.fury.io/wez/gpg.key |
      gpg --dearmor --yes -o "$work/wezterm-fury.gpg"
    sudo install -m 0644 "$work/wezterm-fury.gpg" "$keyring"
  fi

  if [[ ! -f $source ]]; then
    printf '%s\n' \
      'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' \
      > "$work/wezterm.list"
    sudo install -m 0644 "$work/wezterm.list" "$source"
  fi

  sudo apt-get update
  sudo apt-get install -y wezterm
)

install_docker() (
  set -euo pipefail

  local conflicting=(
    docker.io
    docker-compose
    docker-compose-v2
    docker-doc
    podman-docker
    containerd
    runc
  )
  local codename work

  if $dry_run; then
    echo '+ install Docker Engine from download.docker.com'
    return
  fi

  sudo apt-get remove -y "${conflicting[@]}" || true
  sudo install -m 0755 -d /etc/apt/keyrings

  work=$(mktemp -d)
  trap 'rm -rf "$work"' EXIT HUP INT TERM
  curl --retry 3 --retry-all-errors -fsSL \
    https://download.docker.com/linux/ubuntu/gpg \
    -o "$work/docker.asc"
  sudo install -m 0644 "$work/docker.asc" /etc/apt/keyrings/docker.asc

  codename=${UBUNTU_CODENAME:-$VERSION_CODENAME}
  cat > "$work/docker.sources" <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $codename
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF
  sudo install -m 0644 \
    "$work/docker.sources" /etc/apt/sources.list.d/docker.sources

  sudo apt-get update
  sudo apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

  if ! getent group docker >/dev/null; then
    sudo groupadd docker
  fi
  sudo usermod -aG docker "$USER"
)

install_hackgen_font() (
  set -euo pipefail

  local version=v2.10.0
  local work

  if $dry_run; then
    echo "+ install HackGen Nerd Font $version"
    return
  fi

  work=$(mktemp -d)
  trap 'rm -rf "$work"' EXIT HUP INT TERM
  curl --retry 3 --retry-all-errors -fsSL \
    -o "$work/hackgen.zip" \
    "https://github.com/yuru7/HackGen/releases/download/$version/HackGen_NF_$version.zip"
  unzip -q "$work/hackgen.zip" -d "$work/fonts"
  mkdir -p "$HOME/.local/share/fonts"
  find "$work/fonts" -type f -name '*.ttf' \
    -exec cp -f {} "$HOME/.local/share/fonts/" \;
  fc-cache -f
)

install_nextcloud() {
  if $dry_run; then
    echo '+ install Nextcloud Desktop from ppa:nextcloud-devs/client'
    return
  fi

  if ! grep -Rqs \
      'nextcloud-devs/client' \
      /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null; then
    sudo add-apt-repository -y ppa:nextcloud-devs/client
  fi
  sudo apt-get update
  sudo apt-get install -y nextcloud-desktop
}

install_desktop_snaps() {
  local package

  if $dry_run; then
    echo '+ install Bitwarden, Discord, Slack, Vivaldi, and Visual Studio Code snaps'
    return
  fi

  for package in bitwarden discord slack vivaldi; do
    if ! snap list "$package" >/dev/null 2>&1; then
      sudo snap install "$package"
    fi
  done
  if ! snap list code >/dev/null 2>&1; then
    sudo snap install code --classic
  fi
}

install_antigravity() (
  set -euo pipefail

  local keyring=/etc/apt/keyrings/antigravity-repo-key.gpg
  local source=/etc/apt/sources.list.d/antigravity.list
  local work

  if $dry_run; then
    echo '+ install Antigravity from the Google apt repository'
    return
  fi

  sudo install -m 0755 -d /etc/apt/keyrings
  work=$(mktemp -d)
  trap 'rm -rf "$work"' EXIT HUP INT TERM

  if [[ ! -f $keyring ]]; then
    curl --retry 3 --retry-all-errors -fsSL \
      https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg |
      gpg --dearmor --yes -o "$work/antigravity-repo-key.gpg"
    sudo install -m 0644 "$work/antigravity-repo-key.gpg" "$keyring"
  fi

  if [[ ! -f $source ]]; then
    printf '%s\n' \
      'deb [signed-by=/etc/apt/keyrings/antigravity-repo-key.gpg] https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/ antigravity-debian main' \
      > "$work/antigravity.list"
    sudo install -m 0644 "$work/antigravity.list" "$source"
  fi

  sudo apt-get update
  sudo apt-get install -y antigravity
)

install_desktop_extras() {
  install_wezterm
  install_docker
  install_hackgen_font
  install_nextcloud
  install_desktop_snaps
  install_antigravity
}

run sudo apt-get update
install_apt_file "$root/packages/ubuntu/common.txt"
if [[ $profile == host ]]; then
  install_apt_file "$root/packages/ubuntu/host.txt"
fi
if [[ $desktop == true ]]; then
  install_apt_file "$root/packages/ubuntu/desktop.txt"
  install_desktop_extras
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
if [[ $desktop == true ]]; then
  echo "Log out and log back in to use Docker without sudo."
fi
