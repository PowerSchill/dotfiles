#!/usr/bin/env zsh

if command -v bat >/dev/null 2>&1; then
  export MANPAGER="sh -c 'col -bx | bat -l man -p'"
fi


if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

# Install Homebrew Casks in user's Applications directory
export HOMEBREW_CASK_OPTS="--appdir=~/Applications"

if [ -f ~/.config/op/plugins.sh ]; then
  source ~/.config/op/plugins.sh
fi


# [10 Zsh hacks I wish I knew about sooner](https://www.youtube.com/watch?v=3fVAtaGhUyU)

# edit current command line in EDITOR
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^x^e' edit-command-line

# Used to expand commands like '!!' to show what is actually being run
bindkey ' ' magic-space

# Clear screen but keep the buffer
clear-keep-buffer() {
  zle clear-screen
}
zle -N clear-keep-buffer
bindkey '^Xl' clear-keep-buffer
