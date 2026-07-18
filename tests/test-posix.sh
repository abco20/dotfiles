#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_home=$(mktemp -d)
trap 'rm -rf "$test_home"' EXIT

export HOME=$test_home
export DOTFILES_PROFILE=${DOTFILES_PROFILE:-container}
export DOTFILES_DESKTOP=${DOTFILES_DESKTOP:-false}
export DOTFILES_ROBOTICS=${DOTFILES_ROBOTICS:-false}
export DOTFILES_ROS_DISTRO=${DOTFILES_ROS_DISTRO:-}

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
[[ ! -e $HOME/.config/mise/conf.d ]]
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
! grep -R -q 'MISE_LOCKFILE=false' \
  "$root/home" "$root/scripts" "$root/.github" "$root/README.md"
grep -q '^"aqua:rossmacarthur/sheldon" = "latest"$' "$HOME/.config/mise-managed/conf.d/10-common.toml"
[[ -e $HOME/.config/sheldon/plugins.toml ]]
grep -q '^github = "zsh-users/zsh-autosuggestions"$' "$HOME/.config/sheldon/plugins.toml"
grep -q '^github = "zsh-users/zsh-syntax-highlighting"$' "$HOME/.config/sheldon/plugins.toml"
grep -q '^tag = "v0.7.1"$' "$HOME/.config/sheldon/plugins.toml"
grep -q '^tag = "0.8.0"$' "$HOME/.config/sheldon/plugins.toml"
[[ ! -e $HOME/.config/mise-managed/conf.d/25-host-ai-cli.toml ]]
[[ -e $HOME/.config/lazygit/config.yml ]]
zsh -n "$HOME/.zshrc" "$HOME/.config/zsh/main.zsh" "$HOME/.config/zsh/aliases.zsh"
PATH=/usr/bin:/bin zsh -dfc 'source "$HOME/.config/zsh/main.zsh"; [[ $MISE_SYSTEM_CONFIG_DIR == "$HOME/.config/mise-managed" ]]'

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
