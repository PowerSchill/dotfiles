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
