zstyle ":completion:*:commands" rehash 1

# Lines configured by zsh-newuser-install
HISTFILE=~/.histfile
HISTSIZE=1000
SAVEHIST=1000
setopt autocd extendedglob nomatch
unsetopt beep notify
bindkey -d
# End of lines configured by zsh-newuser-install
# The following lines were added by compinstall
zstyle :compinstall filename '$HOME/.zshrc'

autoload -Uz compinit
compinit
# End of lines added by compinstall
eval "$(starship init zsh)"

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


setopt print_eight_bit

alias ls='lsd'
alias l='ls'
alias ll='ls -l'
alias rm='rm -i'

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

autoload history-search-end
zle -N history-beginning-search-backward-end history-search-end
zle -N history-beginning-search-forward-end history-search-end
bindkey "^N" history-beginning-search-forward-end
bindkey "^P" history-beginning-search-backward-end

[ -f ~/.zshrc.local ] && source ~/.zshrc.local
