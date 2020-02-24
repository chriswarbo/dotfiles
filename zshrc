# Lines configured by zsh-newuser-install
HISTFILE=~/.histfile
HISTSIZE=1000
SAVEHIST=1000
bindkey -e
# End of lines configured by zsh-newuser-install
# The following lines were added by compinstall
zstyle :compinstall filename '/Users/chris/.zshrc'

autoload -Uz compinit
compinit
# End of lines added by compinstall

# See https://direnv.net/docs/hook.html
eval "$(direnv hook zsh)"

# Emacs shells don't need a separate pager like less
[[ -n "$INSIDE_EMACS" ]] && export PAGER=cat
