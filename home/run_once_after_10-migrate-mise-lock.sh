#!/usr/bin/env bash
set -euo pipefail

config_root="${XDG_CONFIG_HOME:-$HOME/.config}/mise"
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

printf '%s\n' '# Machine-local mise lockfile.' > "$lock"
empty_system_config=$(mktemp -d)
trap 'rm -rf "$empty_system_config"' EXIT HUP INT TERM

case "$(uname -s)-$(uname -m)" in
  Linux-x86_64) platform=linux-x64 ;;
  Darwin-arm64) platform=macos-arm64 ;;
  *)
    echo "unsupported platform for mise lock migration" >&2
    exit 1
    ;;
esac

MISE_SYSTEM_CONFIG_DIR="$empty_system_config" \
MISE_CONFIG_DIR="$config_root" \
mise lock --global --platform "$platform" --yes
