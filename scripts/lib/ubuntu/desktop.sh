read_packages_by_provider() {
  local file=$1 provider=$2
  awk -v provider="$provider" '
    /^[[:space:]]*#/ { next }
    NF == 0 { next }
    $1 == provider { print $2 }
  ' "$file"
}

desktop_manifests() {
  printf '%s\n' "$root/packages/ubuntu/desktop-core.tsv"
  [[ ${1:-false} == true ]] &&
    printf '%s\n' "$root/packages/ubuntu/desktop-personal.tsv"
}

manifest_has_package() {
  local manifest=$1 provider=$2 wanted=$3 package
  while IFS= read -r package; do
    [[ $package == "$wanted" ]] && return 0
  done < <(read_packages_by_provider "$manifest" "$provider")
  return 1
}

install_desktop_dependencies() {
  local include_personal=$1 manifest packages=() selected=()
  mapfile -t selected < <(desktop_manifests "$include_personal")
  for manifest in "${selected[@]}"; do
    mapfile -t packages < <(read_packages_by_provider "$manifest" apt)
    if ((${#packages[@]})); then
      run sudo apt-get install -y "${packages[@]}"
    fi
  done
}

configure_desktop_repositories() {
  local include_personal=$1 manifest repository selected=()
  mapfile -t selected < <(desktop_manifests "$include_personal")
  for manifest in "${selected[@]}"; do
    while IFS= read -r repository; do
      case $repository in
        wezterm) configure_wezterm_repository ;;
        docker) configure_docker_repository ;;
        nextcloud) configure_nextcloud_repository ;;
        antigravity) configure_antigravity_repository ;;
        *) echo "unsupported desktop repository package: $repository" >&2; return 1 ;;
      esac
    done < <(read_packages_by_provider "$manifest" repository-apt)
  done
}

install_desktop_repository_packages() {
  local include_personal=$1 manifest repository selected=() packages=()
  mapfile -t selected < <(desktop_manifests "$include_personal")
  for manifest in "${selected[@]}"; do
    while IFS= read -r repository; do
      case $repository in
        wezterm) packages+=(wezterm) ;;
        docker) packages+=(docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin) ;;
        nextcloud) packages+=(nextcloud-desktop) ;;
        antigravity) packages+=(antigravity) ;;
      esac
    done < <(read_packages_by_provider "$manifest" repository-apt)
  done
  if ((${#packages[@]})); then
    run sudo apt-get install -y "${packages[@]}"
  fi
}

install_desktop_snap_packages() {
  local include_personal=$1 manifest selected=() packages=()
  mapfile -t selected < <(desktop_manifests "$include_personal")
  for manifest in "${selected[@]}"; do
    mapfile -t packages < <(read_packages_by_provider "$manifest" snap)
    if ((${#packages[@]})); then
      install_snap_packages "${packages[@]}"
    fi
    mapfile -t packages < <(read_packages_by_provider "$manifest" snap-classic)
    if ((${#packages[@]})); then
      install_snap_classic_packages "${packages[@]}"
    fi
  done
}

install_hackgen_font() (
  set -euo pipefail
  local version=v2.10.0 work
  if ${dry_run:-false}; then
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

install_desktop_fonts() {
  local include_personal=$1 manifest font selected=()
  mapfile -t selected < <(desktop_manifests "$include_personal")
  for manifest in "${selected[@]}"; do
    while IFS= read -r font; do
      case $font in
        hackgen) install_hackgen_font ;;
        *) echo "unsupported desktop font: $font" >&2; return 1 ;;
      esac
    done < <(read_packages_by_provider "$manifest" font)
  done
}

configure_docker_user() {
  local core=$root/packages/ubuntu/desktop-core.tsv
  manifest_has_package "$core" repository-apt docker || return
  getent group docker >/dev/null || run sudo groupadd docker
  run sudo usermod -aG docker "$USER"
}

install_desktop_apps() {
  local include_personal=${1:-false}
  install_desktop_dependencies "$include_personal"
  configure_desktop_repositories "$include_personal"
  run sudo apt-get update
  install_desktop_repository_packages "$include_personal"
  install_desktop_snap_packages "$include_personal"
  install_desktop_fonts "$include_personal"
  configure_docker_user
}
