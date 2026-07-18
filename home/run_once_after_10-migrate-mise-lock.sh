#!/usr/bin/env bash
set -euo pipefail

config_root=${DOTFILES_MISE_CONFIG_ROOT:-"${XDG_CONFIG_HOME:-$HOME/.config}/mise"}
config="$config_root/config.toml"
lock="$config_root/mise.lock"
legacy_conf_dir="$config_root/conf.d"

for legacy_file in \
  00-settings.toml \
  10-common.toml \
  20-dev-cli.toml \
  30-host-languages.toml; do
  rm -f "$legacy_conf_dir/$legacy_file"
done
rmdir "$legacy_conf_dir" 2>/dev/null || true

[[ -f $config && -f $lock ]] || exit 0
grep -Fq 'aqua:starship/starship' "$lock" || exit 0
grep -Fq 'aqua:rossmacarthur/sheldon' "$lock" || exit 0

if grep -Fq 'aqua:starship/starship' "$config" &&
   grep -Fq 'aqua:rossmacarthur/sheldon' "$config"; then
  exit 0
fi

command -v mise >/dev/null 2>&1 || {
  echo "mise is required to migrate the machine-local lockfile" >&2
  exit 1
}

temp_root=$(mktemp -d)
lock_candidate="$config_root/.mise.lock.migrate.$$"
trap 'rm -rf "$temp_root"; rm -f "$lock_candidate"' EXIT HUP INT TERM
temp_config_root="$temp_root/mise"
empty_system_config="$temp_root/system"
mkdir -p "$temp_config_root" "$empty_system_config"
cp "$config" "$temp_config_root/config.toml"
printf '%s\n' '# Machine-local mise lockfile.' \
  > "$temp_config_root/mise.lock"

case "$(uname -s)-$(uname -m)" in
  Linux-x86_64) platform=linux-x64 ;;
  Darwin-arm64) platform=macos-arm64 ;;
  *)
    echo "unsupported platform for mise lock migration" >&2
    exit 1
    ;;
esac

MISE_SYSTEM_CONFIG_DIR="$empty_system_config" \
MISE_GLOBAL_CONFIG_FILE="$temp_config_root/config.toml" \
mise -C "$temp_root" lock --global --platform "$platform" --yes

cp "$temp_config_root/mise.lock" "$lock_candidate"
chmod --reference="$lock" "$lock_candidate" 2>/dev/null || chmod 600 "$lock_candidate"
mv "$lock_candidate" "$lock"
