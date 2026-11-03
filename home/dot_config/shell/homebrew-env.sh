#!/bin/sh
# Put Homebrew first on PATH, ahead of any native copy of a Package, wherever this
# Machine keeps it. Sourced by .zshrc and .bashrc.
for _dotfiles_brew in /opt/homebrew/bin/brew /usr/local/bin/brew \
    /home/linuxbrew/.linuxbrew/bin/brew "$HOME/.linuxbrew/bin/brew"; do
    if [ -x "$_dotfiles_brew" ]; then
        eval "$("$_dotfiles_brew" shellenv)"
        break
    fi
done
unset _dotfiles_brew

# Apply writes the Brewfile here. Without this, `brew bundle --global` looks under
# $XDG_CONFIG_HOME/homebrew, which .zshrc sets.
export HOMEBREW_BUNDLE_FILE_GLOBAL="$HOME/.Brewfile"
