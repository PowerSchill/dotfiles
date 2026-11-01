#!/usr/bin/env zsh

if command -v bat >/dev/null 2>&1; then
  export MANPAGER="sh -c 'col -bx | bat -l man -p'"
fi


if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

# Install Homebrew Casks in user's Applications directory
# export HOMEBREW_CASK_OPTS="--appdir=~/Applications"

# 1Password shell plugin wrappers, tracked in this repo instead of the
# `op plugin init` managed ~/.config/op/plugins.sh. See docs/1password-shell-plugins.md.
if [[ -o interactive && -t 0 && -f ~/.config/shell/functions/op-plugins.sh ]]; then
  source ~/.config/shell/functions/op-plugins.sh
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

bindkey -v
