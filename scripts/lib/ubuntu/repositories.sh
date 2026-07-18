configure_wezterm_repository() {
  run sudo install -m 0755 -d /usr/share/keyrings
  install_gpg_key \
    https://apt.fury.io/wez/gpg.key \
    /usr/share/keyrings/wezterm-fury.gpg \
    true
  install_source_file \
    "$root/packages/ubuntu/sources/wezterm.list" \
    /etc/apt/sources.list.d/wezterm.list
}

configure_docker_repository() (
  set -euo pipefail
  local conflicting=(
    docker.io docker-compose docker-compose-v2 docker-doc
    podman-docker containerd runc
  )
  local installed=()
  local codename package work

  for package in "${conflicting[@]}"; do
    if dpkg-query -W -f='${db:Status-Abbrev}' "$package" 2>/dev/null |
        grep -q '^ii'; then
      installed+=("$package")
    fi
  done
  if ((${#installed[@]})); then
    run sudo apt-get remove -y "${installed[@]}"
  fi
  run sudo install -m 0755 -d /etc/apt/keyrings
  install_gpg_key \
    https://download.docker.com/linux/ubuntu/gpg \
    /etc/apt/keyrings/docker.asc

  codename=${UBUNTU_CODENAME:-$VERSION_CODENAME}
  work=$(mktemp -d)
  trap 'rm -rf "$work"' EXIT HUP INT TERM
  sed "s/@CODENAME@/$codename/g" \
    "$root/packages/ubuntu/sources/docker.sources.tmpl" \
    > "$work/docker.sources"
  install_source_file \
    "$work/docker.sources" \
    /etc/apt/sources.list.d/docker.sources
)

configure_nextcloud_repository() {
  if ! grep -Rqs 'nextcloud-devs/client' \
      /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null; then
    run sudo add-apt-repository -y -n ppa:nextcloud-devs/client
  fi
}

configure_antigravity_repository() {
  run sudo install -m 0755 -d /etc/apt/keyrings
  install_gpg_key \
    https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg \
    /etc/apt/keyrings/antigravity-repo-key.gpg \
    true
  install_source_file \
    "$root/packages/ubuntu/sources/antigravity.list" \
    /etc/apt/sources.list.d/antigravity.list
}
