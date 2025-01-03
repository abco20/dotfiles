zstyle ":completion:*:commands" rehash 1

# Lines configured by zsh-newuser-install
HISTFILE=~/.histfile
HISTSIZE=10000
SAVEHIST=10000
setopt autocd extendedglob nomatch
unsetopt beep notify
bindkey -d
# End of lines configured by zsh-newuser-install
# The following lines were added by compinstall
zstyle :compinstall filename '$HOME/.zshrc'

autoload -Uz compinit
compinit
# End of lines added by compinstall

export LANG=en_US.UTF-8
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

autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search

[[ -n "${key[Up]}"   ]] && bindkey -- "${key[Up]}"   up-line-or-beginning-search
[[ -n "${key[Down]}" ]] && bindkey -- "${key[Down]}" down-line-or-beginning-search


setopt print_eight_bit

case ${OSTYPE} in
	darwin*)
		#mac
        source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh
		source $(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
        ;;
	linux*)
		#linux
		source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
        source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
	;;
esac

eval "$(starship init zsh)"

autoload history-search-end
zle -N history-beginning-search-backward-end history-search-end
zle -N history-beginning-search-forward-end history-search-end
bindkey "^N" history-beginning-search-forward-end
bindkey "^P" history-beginning-search-backward-end

DOTFILES_DIR=$HOME/dotfiles

source $DOTFILES_DIR/zsh/alias.zsh

[ -f ~/.zshrc.local ] && source ~/.zshrc.local
[ -d /opt/ros ] && source $DOTFILES_DIR/zsh/ros.zsh
