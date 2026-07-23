export LANG="${LANG:-en_US.UTF-8}"
export MISE_SYSTEM_CONFIG_DIR="$HOME/.config/mise-managed"
export MISE_CONFIG_DIR="$HOME/.config/mise"

HISTFILE="${ZDOTDIR:-$HOME}/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000

setopt autocd extendedglob hist_ignore_dups share_history print_eight_bit
unsetopt beep notify
bindkey -e

autoload -Uz compinit
compinit
zstyle ':completion:*:commands' rehash 1
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*:default*' menu true select
zstyle ':completion:*' completer _complete _approximate _prefix

autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search

if command -v mise >/dev/null 2>&1; then
  _abco20_mise=mise
elif [[ -x "$HOME/.local/bin/mise" ]]; then
  _abco20_mise="$HOME/.local/bin/mise"
fi
if [[ -n ${_abco20_mise:-} ]]; then
  eval "$("$_abco20_mise" activate zsh)"
fi

[[ -r "$HOME/.config/zsh/aliases.zsh" ]] && source "$HOME/.config/zsh/aliases.zsh"
[[ -r "$HOME/.config/zsh/ros.zsh" ]] && source "$HOME/.config/zsh/ros.zsh"

if [[ -n ${_abco20_mise:-} ]]; then
  eval "$("$_abco20_mise" completion zsh)"
  unset _abco20_mise
fi

if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

# Sheldon keeps syntax highlighting last, after widgets and aliases are defined.
if command -v sheldon >/dev/null 2>&1; then
  eval "$(sheldon source)"
fi
