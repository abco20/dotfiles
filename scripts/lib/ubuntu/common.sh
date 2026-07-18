run() {
  if ${dry_run:-false}; then
    printf '+ '
    printf '%q ' "$@"
    printf '\n'
  else
    "$@"
  fi
}

install_apt_file() {
  local file=$1 packages=()
  mapfile -t packages < <(
    sed -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d' "$file"
  )
  if ((${#packages[@]})); then
    run sudo apt-get install -y "${packages[@]}"
  fi
}

install_snap_packages() {
  local package
  for package in "$@"; do
    if ${dry_run:-false} || ! snap list "$package" >/dev/null 2>&1; then
      run sudo snap install "$package"
    fi
  done
}

install_snap_classic_packages() {
  local package
  for package in "$@"; do
    if ${dry_run:-false} || ! snap list "$package" >/dev/null 2>&1; then
      run sudo snap install "$package" --classic
    fi
  done
}

install_gpg_key() (
  set -euo pipefail
  local url=$1 destination=$2 dearmor=${3:-false} work

  if ${dry_run:-false}; then
    printf '+ install GPG key %q to %q\n' "$url" "$destination"
    return
  fi

  work=$(mktemp -d)
  trap 'rm -rf "$work"' EXIT HUP INT TERM
  if [[ $dearmor == true ]]; then
    curl --retry 3 --retry-all-errors -fsSL "$url" |
      gpg --dearmor --yes -o "$work/key"
  else
    curl --retry 3 --retry-all-errors -fsSL -o "$work/key" "$url"
  fi

  if sudo test -f "$destination" &&
      sudo cmp -s "$work/key" "$destination"; then
    return
  fi
  sudo install -m 0644 "$work/key" "$destination"
)

install_source_file() {
  local source=$1 destination=$2
  if ${dry_run:-false}; then
    printf '+ install source file %q to %q\n' "$source" "$destination"
    return
  fi
  if sudo test -f "$destination" &&
      sudo cmp -s "$source" "$destination"; then
    return
  fi
  sudo install -m 0644 "$source" "$destination"
}
