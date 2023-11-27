zstyle ":completion:*:commands" rehash 1

# Lines configured by zsh-newuser-install
HISTFILE=~/.histfile
HISTSIZE=1000
SAVEHIST=1000
setopt autocd extendedglob nomatch
unsetopt beep notify
bindkey -e
# End of lines configured by zsh-newuser-install
# The following lines were added by compinstall
zstyle :compinstall filename '/home/fdsdf/.zshrc'

autoload -Uz compinit
compinit
# End of lines added by compinstall
eval "$(starship init zsh)"

export LANG=ja_JP.UTF-8
export KCODE=u  # KCODEにUTF-8を設定

setopt hist_ignore_dups
setopt share_history

autoload -Uz colors
colors

autoload -Uz compinit
compinit

zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*:default*' menu true select
zstyle ':completion:*:default' list-colors di=4 ex=33 '=*.c=35'
zstyle ':completion:*' completer _complete _approximate
zstyle ':completion:*' completer _complete _correct
zstyle ':completion:*' completer _complete _approximate _prefix


setopt print_eight_bit

alias ls='lsd'
alias l='ls'
alias ll='ls -l'
alias rm='rm -i'
alias cat='bat'
source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh

autoload history-search-end
zle -N history-beginning-search-backward-end history-search-end
zle -N history-beginning-search-forward-end history-search-end
bindkey "^N" history-beginning-search-forward-end
bindkey "^P" history-beginning-search-backward-end
