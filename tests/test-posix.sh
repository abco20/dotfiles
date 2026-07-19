#!/usr/bin/env bash
set -Eeuo pipefail

trap 'status=$?; echo "POSIX test failed at line $LINENO" >&2; exit "$status"' ERR

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_home=$(mktemp -d)
trap 'rm -rf "$test_home"' EXIT

export HOME=$test_home
export XDG_CONFIG_HOME="$HOME/xdg-config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"
export MISE_SYSTEM_CONFIG_DIR="$HOME/.config/mise-managed"
export MISE_CONFIG_DIR="$HOME/.config/mise"
export DOTFILES_PROFILE=${DOTFILES_PROFILE:-container}
export DOTFILES_DESKTOP=${DOTFILES_DESKTOP:-false}
export DOTFILES_ROBOTICS=${DOTFILES_ROBOTICS:-false}
export DOTFILES_ROS_DISTRO=${DOTFILES_ROS_DISTRO:-}

core_manifest=$root/packages/ubuntu/desktop-core.tsv
personal_manifest=$root/packages/ubuntu/desktop-personal.tsv
[[ -f $core_manifest && -f $personal_manifest ]]

# shellcheck source=../scripts/lib/ubuntu/common.sh
source "$root/scripts/lib/ubuntu/common.sh"
# shellcheck source=../scripts/lib/ubuntu/repositories.sh
source "$root/scripts/lib/ubuntu/repositories.sh"
# shellcheck source=../scripts/lib/ubuntu/desktop.sh
source "$root/scripts/lib/ubuntu/desktop.sh"

validate_desktop_manifest() {
  local file=$1 provider package
  while read -r provider package; do
    [[ -z ${provider:-} || $provider == \#* ]] && continue
    [[ -n ${package:-} ]]
    case $provider in
      apt|repository-apt|snap|snap-classic|font) ;;
      *) echo "unknown provider in $file: $provider" >&2; return 1 ;;
    esac
  done < "$file"
}

validate_desktop_manifest "$core_manifest"
validate_desktop_manifest "$personal_manifest"
mapfile -t core_classic < <(read_packages_by_provider "$core_manifest" snap-classic)
[[ ${core_classic[*]} == code ]]
mapfile -t core_personal < <(
  read_packages_by_provider "$core_manifest" snap
)
[[ ${#core_personal[@]} == 0 ]]
mapfile -t personal_snaps < <(
  read_packages_by_provider "$personal_manifest" snap
)
[[ " ${personal_snaps[*]} " == *' bitwarden '* ]]
[[ " ${personal_snaps[*]} " == *' discord '* ]]
[[ " ${personal_snaps[*]} " == *' slack '* ]]
[[ " ${personal_snaps[*]} " == *' vivaldi '* ]]

if "$root/scripts/bootstrap-linux.sh" \
    --profile container --desktop --dry-run >/dev/null 2>&1; then
  echo 'container + desktop was accepted' >&2
  exit 1
fi
if "$root/scripts/bootstrap-linux.sh" \
    --profile host --personal-apps --dry-run >/dev/null 2>&1; then
  echo 'personal apps without desktop was accepted' >&2
  exit 1
fi

test_desktop_dry_run() {
  local work fake_bin core_output personal_output
  local VERSION_CODENAME=noble UBUNTU_CODENAME=noble
  work=$(mktemp -d)
  fake_bin=$work/fake-bin
  mkdir -p "$fake_bin"
  printf '%s\n' '#!/bin/sh' 'echo "sudo unexpectedly executed" >&2' 'exit 99' > "$fake_bin/sudo"
  printf '%s\n' '#!/bin/sh' 'echo "snap unexpectedly executed" >&2' 'exit 99' > "$fake_bin/snap"
  chmod +x "$fake_bin/sudo" "$fake_bin/snap"

  PATH="$fake_bin:$PATH" "$root/scripts/bootstrap-linux.sh" \
    --profile host --desktop --dry-run > "$work/core"
  core_output=$(<"$work/core")
  [[ $core_output == *'wezterm'* ]]
  [[ $core_output == *'docker-ce'* ]]
  [[ $core_output == *'snap install code --classic'* ]]
  [[ $core_output != *'bitwarden'* ]]
  [[ $core_output != *'nextcloud'* ]]
  [[ $core_output != *'antigravity'* ]]

  PATH="$fake_bin:$PATH" "$root/scripts/bootstrap-linux.sh" \
    --profile host --desktop --personal-apps --dry-run > "$work/personal"
  personal_output=$(<"$work/personal")
  [[ $personal_output == *'bitwarden'* ]]
  [[ $personal_output == *'nextcloud-desktop'* ]]
  [[ $personal_output == *'antigravity'* ]]

  dry_run=true
  install_desktop_apps true > "$work/desktop-only"
  [[ $(grep -c '^+ sudo apt-get update ' "$work/desktop-only") == 1 ]]
  dry_run=false
  rm -rf "$work"
}

test_macos_personal_selection() {
  local work fake_bin core_output ci_output personal_output
  work=$(mktemp -d)
  fake_bin=$work/fake-bin
  mkdir -p "$fake_bin"
  printf '%s\n' '#!/bin/sh' 'exit 0' > "$fake_bin/brew"
  chmod +x "$fake_bin/brew"

  PATH="$fake_bin:$PATH" "$root/scripts/bootstrap-macos.sh" \
    --profile host --desktop --dry-run > "$work/core"
  core_output=$(<"$work/core")
  [[ $core_output == *'Brewfile.desktop'* ]]
  [[ $core_output == *'Brewfile.desktop-manual'* ]]
  [[ $core_output != *'Brewfile.personal'* ]]

  PATH="$fake_bin:$PATH" "$root/scripts/bootstrap-macos.sh" \
    --profile host --desktop --skip-manual-desktop --dry-run > "$work/ci"
  ci_output=$(<"$work/ci")
  [[ $ci_output == *'Brewfile.desktop'* ]]
  [[ $ci_output != *'Brewfile.desktop-manual'* ]]

  PATH="$fake_bin:$PATH" "$root/scripts/bootstrap-macos.sh" \
    --profile host --desktop --personal-apps --dry-run > "$work/personal"
  personal_output=$(<"$work/personal")
  [[ $personal_output == *'Brewfile.desktop'* ]]
  [[ $personal_output == *'Brewfile.personal'* ]]
  if PATH="$fake_bin:$PATH" "$root/scripts/bootstrap-macos.sh" \
      --profile host --personal-apps --dry-run >/dev/null 2>&1; then
    echo 'macOS personal apps without desktop was accepted' >&2
    exit 1
  fi
  if PATH="$fake_bin:$PATH" "$root/scripts/bootstrap-macos.sh" \
      --profile host --skip-manual-desktop --dry-run >/dev/null 2>&1; then
    echo 'macOS manual desktop skip without desktop was accepted' >&2
    exit 1
  fi
  rm -rf "$work"
}

test_snap_classic_behavior() {
  local work fake_bin
  work=$(mktemp -d)
  fake_bin=$work/fake-bin
  mkdir -p "$fake_bin"
  printf '%s\n' '#!/bin/sh' 'if [ "$1" = list ]; then exit 1; fi' 'exit 0' > "$fake_bin/snap"
  printf '%s\n' '#!/bin/sh' 'printf "%s\\n" "$*" >> "$COMMAND_LOG"' '"$@"' > "$fake_bin/sudo"
  chmod +x "$fake_bin/snap" "$fake_bin/sudo"
  COMMAND_LOG=$work/commands PATH="$fake_bin:$PATH" \
    install_snap_classic_packages code
  grep -Fxq 'snap install code --classic' "$work/commands"
  rm -rf "$work"
}

test_source_file_update() {
  local work fake_bin source destination
  work=$(mktemp -d)
  fake_bin=$work/fake-bin
  source=$work/source.list
  destination=$work/installed.list
  mkdir -p "$fake_bin"
  printf '%s\n' '#!/bin/sh' '"$@"' > "$fake_bin/sudo"
  chmod +x "$fake_bin/sudo"
  printf '%s\n' 'first content' > "$source"
  PATH="$fake_bin:$PATH" install_source_file "$source" "$destination"
  cmp -s "$source" "$destination"
  printf '%s\n' 'changed content' > "$source"
  PATH="$fake_bin:$PATH" install_source_file "$source" "$destination"
  cmp -s "$source" "$destination"
  rm -rf "$work"
}

test_desktop_dry_run
test_macos_personal_selection
test_snap_classic_behavior
test_source_file_update

grep -Fxq 'cask "docker-desktop"' \
  "$root/packages/macos/Brewfile.desktop-manual"
! grep -Fxq 'brew "mise"' "$root/packages/macos/Brewfile.common"
grep -Fq 'mise_version=${MISE_VERSION:-v2026.7.7}' \
  "$root/scripts/bootstrap-macos.sh"
grep -Fq 'mise_bin="$HOME/.local/bin/mise"' \
  "$root/scripts/bootstrap-macos.sh"
grep -Fq 'MISE_INSTALL_PATH="$mise_bin"' \
  "$root/scripts/bootstrap-macos.sh"
grep -Fq 'aqua:twpayne/chezmoi@2.71.0' \
  "$root/scripts/bootstrap-macos.sh"
grep -Fq 'install --jobs=1' "$root/scripts/bootstrap-macos.sh"
for cask in visual-studio-code wezterm; do
  grep -Fxq "cask \"$cask\"" "$root/packages/macos/Brewfile.desktop"
  ! grep -Fxq "cask \"$cask\"" "$root/packages/macos/Brewfile.personal"
done
for cask in docker-desktop font-hackgen-nerd; do
  grep -Fxq "cask \"$cask\"" "$root/packages/macos/Brewfile.desktop-manual"
done
! grep -Fq 'docker-desktop' "$root/packages/macos/Brewfile.desktop"
! grep -Fq 'font-hackgen-nerd' "$root/packages/macos/Brewfile.desktop"
for cask in antigravity bitwarden discord nextcloud slack vivaldi; do
  grep -Fxq "cask \"$cask\"" "$root/packages/macos/Brewfile.personal"
  ! grep -Fxq "cask \"$cask\"" "$root/packages/macos/Brewfile.desktop"
done
grep -Fq 'export MISE_SYSTEM_CONFIG_DIR="$HOME/.config/mise-managed"' \
  "$root/scripts/bootstrap-linux.sh"
grep -Fq 'export MISE_CONFIG_DIR="$HOME/.config/mise"' \
  "$root/scripts/bootstrap-linux.sh"
! grep -Fq 'mise install --locked' "$root/scripts/update-mise-lock.sh"
! grep -R \
  '\${XDG_CONFIG_HOME:-\$HOME/.config}/mise' \
  "$root/home" "$root/scripts" "$root/.github" "$root/tests"

test_modifier() {
  local script=$1 work original first second candidate
  work=$(mktemp -d)

  : > "$work/input"
  sh "$script" < "$work/input" > "$work/output"
  [[ $(grep -c '^# >>> abco20 dotfiles >>>$' "$work/output") == 1 ]]

  printf '%s\n' 'before = true' 'after = true' > "$work/input"
  sh "$script" < "$work/input" > "$work/output"
  grep -q '^before = true$' "$work/output"
  grep -q '^after = true$' "$work/output"

  printf '%s\n' \
    'before = true' \
    '# >>> abco20 dotfiles >>>' \
    'stale managed content' \
    '# <<< abco20 dotfiles <<<' \
    'after = true' > "$work/input"
  sh "$script" < "$work/input" > "$work/output"
  ! grep -q '^stale managed content$' "$work/output"
  grep -q '^before = true$' "$work/output"
  grep -q '^after = true$' "$work/output"
  first=$(sha256sum "$work/output")
  sh "$script" < "$work/output" > "$work/output.next"
  second=$(sha256sum "$work/output.next")
  [[ ${first%% *} == "${second%% *}" ]]

  for malformed in start-only end-only duplicate-start duplicate-end reversed nested; do
    case $malformed in
      start-only)
        printf '%s\n' 'keep = true' '# >>> abco20 dotfiles >>>' 'do not lose' > "$work/target"
        ;;
      end-only)
        printf '%s\n' 'keep = true' '# <<< abco20 dotfiles <<<' > "$work/target"
        ;;
      duplicate-start)
        printf '%s\n' '# >>> abco20 dotfiles >>>' '# >>> abco20 dotfiles >>>' '# <<< abco20 dotfiles <<<' > "$work/target"
        ;;
      duplicate-end)
        printf '%s\n' '# >>> abco20 dotfiles >>>' '# <<< abco20 dotfiles <<<' '# <<< abco20 dotfiles <<<' > "$work/target"
        ;;
      reversed)
        printf '%s\n' '# <<< abco20 dotfiles <<<' '# >>> abco20 dotfiles >>>' > "$work/target"
        ;;
      nested)
        printf '%s\n' '# >>> abco20 dotfiles >>>' '# >>> abco20 dotfiles >>>' '# <<< abco20 dotfiles <<<' '# <<< abco20 dotfiles <<<' > "$work/target"
        ;;
    esac
    original=$(sha256sum "$work/target")
    candidate="$work/$malformed.out"
    if sh "$script" < "$work/target" > "$candidate" 2> "$work/error"; then
      echo "$script accepted malformed markers: $malformed" >&2
      exit 1
    fi
    [[ ! -s $candidate ]]
    [[ $original == "$(sha256sum "$work/target")" ]]
    [[ -s $work/error ]]
  done

  rm -rf "$work"
}

test_modifier "$root/home/modify_dot_zshrc"
test_modifier "$root/home/modify_dot_gitconfig"
test_modifier "$root/home/private_dot_config/git/modify_config"

test_lock_migration_failure() {
  local work fake_bin config_root lock_before
  work=$(mktemp -d)
  fake_bin="$work/bin"
  config_root="$work/mise"
  mkdir -p "$fake_bin" "$config_root"
  printf '%s\n' '[tools]' 'deno = "latest"' > "$config_root/config.toml"
  printf '%s\n' \
    '# existing machine-local lock content' \
    'aqua:starship/starship' \
    'aqua:rossmacarthur/sheldon' > "$config_root/mise.lock"
  printf '%s\n' '#!/bin/sh' 'exit 1' > "$fake_bin/mise"
  chmod +x "$fake_bin/mise"
  lock_before=$(sha256sum "$config_root/mise.lock")
  if DOTFILES_MISE_CONFIG_ROOT="$config_root" \
      PATH="$fake_bin:/usr/bin:/bin" \
      bash "$root/home/run_once_after_10-migrate-mise-lock.sh"; then
    echo "mise lock migration unexpectedly succeeded" >&2
    exit 1
  fi
  [[ $lock_before == "$(sha256sum "$config_root/mise.lock")" ]]
  rm -rf "$work"
}

test_lock_migration_failure
chezmoi execute-template \
  --source "$root/home" \
  --file "$root/home/private_dot_config/zsh/ros.zsh.tmpl" \
  --override-data '{"rosDistro":"","chezmoi":{"os":"darwin"}}' >/dev/null
chezmoi execute-template \
  --source "$root/home" \
  --file "$root/home/private_dot_config/zsh/ros.zsh.tmpl" \
  --override-data '{"rosDistro":"","chezmoi":{"os":"windows"}}' >/dev/null
windows_ignore=$(chezmoi execute-template \
  --source "$root/home" \
  --file "$root/home/.chezmoiignore" \
  --override-data '{"profile":"host","desktop":false,"robotics":false,"chezmoi":{"os":"windows"}}')
grep -q '^10-migrate-mise-lock.sh$' <<< "$windows_ignore"
! grep -q '^10-migrate-mise-lock.ps1$' <<< "$windows_ignore"
grep -q '^.config/sheldon$' <<< "$windows_ignore"

printf '%s\n' 'export APP_ADDED=1' > "$HOME/.zshrc"
mkdir -p "$HOME/.config/git" "$HOME/.config/mise/conf.d"
printf '%s\n' '[user]' '    name = Existing User' > "$HOME/.config/git/config"
printf '%s\n' \
  '[user]' \
  '    email = existing@example.com' \
  '[include]' \
  '    path = ~/.config/git/.gitconfig' \
  '    path = ~/.config/git/company.gitconfig' > "$HOME/.gitconfig"
printf '%s\n' '# legacy shared fragment' > "$HOME/.config/mise/conf.d/10-common.toml"
cp "$root/home/private_dot_config/mise-managed/mise.lock" \
  "$HOME/.config/mise/mise.lock"
chezmoi init --apply --source "$root"
printf '%s\n' '[tools]' 'deno = "latest"' >> "$HOME/.config/mise/config.toml"
printf '%s\n' '# keep local lock content' >> "$HOME/.config/mise/mise.lock"
first=$(sha256sum "$HOME/.zshrc")
git_first=$(sha256sum "$HOME/.config/git/config")
git_entry_first=$(sha256sum "$HOME/.gitconfig")
chezmoi apply
second=$(sha256sum "$HOME/.zshrc")
git_second=$(sha256sum "$HOME/.config/git/config")
git_entry_second=$(sha256sum "$HOME/.gitconfig")

[[ $first == "$second" ]]
[[ $git_first == "$git_second" ]]
[[ $git_entry_first == "$git_entry_second" ]]
[[ $(grep -c '^# >>> abco20 dotfiles >>>$' "$HOME/.zshrc") == 1 ]]
[[ $(grep -c '^# >>> abco20 dotfiles >>>$' "$HOME/.config/git/config") == 1 ]]
[[ $(grep -c '^# >>> abco20 dotfiles >>>$' "$HOME/.gitconfig") == 1 ]]
grep -q '^export APP_ADDED=1$' "$HOME/.zshrc"
grep -q '^deno = "latest"$' "$HOME/.config/mise/config.toml"
grep -q '^# keep local lock content$' "$HOME/.config/mise/mise.lock"
for legacy_file in \
  00-settings.toml \
  10-common.toml \
  20-dev-cli.toml \
  30-host-languages.toml; do
  [[ ! -e $HOME/.config/mise/conf.d/$legacy_file ]]
done
! grep -q 'aqua:starship/starship' "$HOME/.config/mise/mise.lock"
grep -q '^    name = Existing User$' "$HOME/.config/git/config"
grep -q '^    email = existing@example.com$' "$HOME/.gitconfig"
! grep -q '~/.config/git/.gitconfig' "$HOME/.gitconfig"
grep -q '^    path = ~/.config/git/company.gitconfig$' "$HOME/.gitconfig"
grep -q 'path = ~/.config/git/config' "$HOME/.gitconfig"
grep -q 'path = ~/.config/git/config.dotfiles' "$HOME/.config/git/config"
[[ -e $HOME/.config/git/config.dotfiles ]]
[[ $(git config --get init.defaultBranch) == main ]]
[[ $(git config --get core.pager) == delta ]]
git config --global --list >/dev/null
[[ -e $HOME/.config/mise-managed/conf.d/20-dev-cli.toml ]]
[[ -e $HOME/.config/mise-managed/conf.d/00-settings.toml ]]
[[ -e $HOME/.config/mise/config.toml ]]
[[ -e $HOME/.config/mise/mise.lock ]]
[[ -e $HOME/.config/mise-managed/mise.lock ]]
grep -q '^lockfile = true$' "$HOME/.config/mise-managed/conf.d/00-settings.toml"
grep -q '^export MISE_SYSTEM_CONFIG_DIR=' "$HOME/.config/zsh/main.zsh"
grep -q '^export MISE_CONFIG_DIR=' "$HOME/.config/zsh/main.zsh"
! grep -R -q 'MISE_LOCKFILE=false' \
  "$root/home" "$root/scripts" "$root/.github" "$root/README.md"
grep -Fq '"aqua:rossmacarthur/sheldon" = {' "$HOME/.config/mise-managed/conf.d/10-common.toml"
grep -Fq 'os = ["linux", "macos"]' "$HOME/.config/mise-managed/conf.d/10-common.toml"
[[ -e $HOME/.config/sheldon/plugins.toml ]]
grep -q '^github = "zsh-users/zsh-autosuggestions"$' "$HOME/.config/sheldon/plugins.toml"
grep -q '^github = "zsh-users/zsh-syntax-highlighting"$' "$HOME/.config/sheldon/plugins.toml"
grep -q '^tag = "v0.7.1"$' "$HOME/.config/sheldon/plugins.toml"
grep -q '^tag = "0.8.0"$' "$HOME/.config/sheldon/plugins.toml"
[[ ! -e $HOME/.config/mise-managed/conf.d/25-host-ai-cli.toml ]]
[[ -e $HOME/.config/lazygit/config.yml ]]
zsh -n "$HOME/.zshrc" "$HOME/.config/zsh/main.zsh" "$HOME/.config/zsh/aliases.zsh"
PATH=/usr/bin:/bin zsh -dfc '
  source "$HOME/.config/zsh/main.zsh"
  [[ $MISE_SYSTEM_CONFIG_DIR == "$HOME/.config/mise-managed" ]]
  [[ $MISE_CONFIG_DIR == "$HOME/.config/mise" ]]
'

if [[ $DOTFILES_PROFILE == container ]]; then
  [[ ! -e $HOME/.config/mise-managed/conf.d/30-host-languages.toml ]]
else
  [[ -e $HOME/.config/mise-managed/conf.d/30-host-languages.toml ]]
fi
if [[ $DOTFILES_DESKTOP == true ]]; then
  [[ -e $HOME/.config/wezterm/wezterm.lua ]]
  [[ -e $HOME/.config/mpv/mpv.conf ]]
  [[ ! -e $HOME/.config/mpv/mpv.config ]]
fi
if [[ $DOTFILES_ROBOTICS == true ]]; then
  [[ -e $HOME/.config/zsh/ros.zsh ]]
  [[ -e $HOME/.config/cyclonedds.xml ]]
fi

echo "posix tests passed"
