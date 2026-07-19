if (( $+commands[lsd] )); then
  alias ls='lsd'
fi
alias l='ls'
alias ll='ls -l'

if (( $+commands[bat] )); then
  alias cat='bat'
elif (( $+commands[batcat] )); then
  alias cat='batcat'
fi

if (( $+commands[nvim] )); then
  alias vi='nvim'
  alias vim='nvim'
fi

if (( $+commands[trash-put] )); then
  alias rm='trash-put'
else
  alias rm='rm -i'
fi
