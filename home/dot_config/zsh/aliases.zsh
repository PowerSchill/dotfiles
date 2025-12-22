#!/usr/bin/env zsh

#═══════════════════════════════════════════════════════════════════════════════
# NAVIGATION & DIRECTORY
#═══════════════════════════════════════════════════════════════════════════════

if command -v zoxide >/dev/null 2>&1; then
  alias cd='z'
fi

# Directory navigation shortcuts
alias ..='cd ..'
alias ...='cd ../../..'
alias ....='cd ../../../..'
alias .....='cd ../../../../..'
alias .4='cd ../../../..'
alias .5='cd ../../../../..'
alias cd..='cd ..'

# Jump to git repo root
alias gt='cd "$(git rev-parse --show-toplevel)"'

# Quick access to common directories
alias db="cd ~/Library/CloudStorage/Dropbox"

#═══════════════════════════════════════════════════════════════════════════════
# FILE LISTING (EZA)
#═══════════════════════════════════════════════════════════════════════════════

export LSCOLORS='Gxfxcxdxdxegedabagacad'

# Basic listing
alias ls="eza --color=always --icons=always --group-directories-first"
alias l='eza --color=always --icons=always'
alias la='eza --color=always --icons=always --all'

# Long format with git info
alias ll="eza --color=always --icons=always --group-directories-first --long --git --no-user --no-time --no-permissions"
alias lla="eza --color=always --icons=always --group-directories-first --long --git --no-user --no-time --no-permissions --all"
alias llt="eza --color=always --icons=always --group-directories-first --long --git --no-user --time-style=long-iso --no-permissions --all"

# Filtered views
alias llf="eza --color=always --icons=always --group-directories-first --long --git --no-user --no-time --no-permissions --all --only-files"
alias lld="eza --color=always --icons=always --group-directories-first --long --git --no-user --no-time --no-permissions --only-dirs"

# Sorted listings
alias lk='eza --color=always --icons=always --long --sort=size'           # Sort by size
alias lt='eza --color=always --icons=always --long --sort=modified'       # Sort by date
alias lr='eza --color=always --icons=always --long --recurse --level=2'   # Recursive

# Tree view
alias tree='tree -Csuh'

# Tree function with smart defaults
function t() {
  # Defaults to 3 levels deep, do more with `t 5` or `t 1`
  tree -I '.git|node_modules|bower_components|.DS_Store' --dirsfirst --filelimit 15 -L ${1:-3} -aC $2
}

#═══════════════════════════════════════════════════════════════════════════════
# FILE OPERATIONS
#═══════════════════════════════════════════════════════════════════════════════

# Safe operations (prompt before overwrite/delete)
alias cp='cp -i'
alias mv='mv -i'
alias rm='trash'  # Use trash instead of rm (install via: brew install trash)

# Resume downloads by default
alias wget='wget -c'

# Secure file deletion
function shred-file() {
  echo "⚠️  This will permanently delete: $@"
  read "?Continue? (y/N) " confirm
  [[ "$confirm" == "y" ]] && command shred -u "$@" || echo "Cancelled."
}
alias shred='shred-file'

#═══════════════════════════════════════════════════════════════════════════════
# macOS SPECIFIC
#═══════════════════════════════════════════════════════════════════════════════

if [[ "$OSTYPE" == "darwin"* ]]; then
  # Application launchers
  alias preview="open -a '$PREVIEW'"
  alias safari="open -a safari"
  alias firefox="open -a firefox"
  alias chrome="open -a google\ chrome"
  alias f='open -a Finder'

  # Quick Look from terminal
  alias ql="qlmanage -px &>/dev/null"

  # Copy current directory path to clipboard
  alias cpwd='pwd | tr -d "\n" | pbcopy'

  # Toggle wifi (usage: wifi on/off)
  alias wifi="networksetup -setairportpower en0"

  # Clean up .DS_Store files
  alias dsclean='find . -type f -name .DS_Store -delete'
fi

#═══════════════════════════════════════════════════════════════════════════════
# GIT
#═══════════════════════════════════════════════════════════════════════════════

alias get="git clone"
alias gd="git diff"
alias gs="git status -bs"

# Remove git from folder
alias degit="find . -name '.git' -exec rm -rf {} \;"

# Auto-stage all changes (add/remove)
alias gitar="git ls-files -d -m -o -z --exclude-standard | xargs -0 git update-index --add --remove"

# Untrack files in .gitignore (after updating .gitignore)
alias gri="git ls-files --ignored --exclude-standard -z | xargs -0 git rm -r --cached"

# Open changed files in editor
alias fix="git diff --name-only | uniq | xargs \${EDITOR:-code}"

# Open git repo in Tower
alias gtower='gittower "$(git rev-parse --show-toplevel)"'

#═══════════════════════════════════════════════════════════════════════════════
# DEVELOPMENT TOOLS
#═══════════════════════════════════════════════════════════════════════════════

# Ruby/Bundler
alias b="bundle"
alias bi="bundle install"
alias bu="bundle update"

function be() {
  if [[ $1 != */* ]]; then
    bundle exec "bin/$1" "${@:2}"
  else
    bundle exec "$@"
  fi
}

# Node/NPM
alias npmg="npm install -g"

# Kitchen/Chef
alias dokken="KITCHEN_LOCAL_YAML=kitchen.dokken.yml kitchen"

#═══════════════════════════════════════════════════════════════════════════════
# PROCESS MANAGEMENT
#═══════════════════════════════════════════════════════════════════════════════

alias cpu='top -o cpu'
alias mem='top -o rsize'
alias psgrep='pgrep -afil'

# Search for TODO/FIXME in code
function todos() {
  if command -v rg &> /dev/null; then
    rg --no-heading --color=always "(TODO|FIXME):" | sed -E "s/(.*:[[:digit:]]+):.*((TODO|FIXME):.*)/\2 :>> \1/"
  else
    ack --nobreak --nocolor "(TODO|FIXME):" | sed -E "s/(.*:[[:digit:]]+):.*((TODO|FIXME):.*)/\2 :>> \1/" | grep -E --color=always ":>>.*:\d+"
  fi
}

#═══════════════════════════════════════════════════════════════════════════════
# TMUX
#═══════════════════════════════════════════════════════════════════════════════

alias takeover='tmux detach -a'
alias tmac='tmux new -A -s'

#═══════════════════════════════════════════════════════════════════════════════
# NETWORK & SYSTEM
#═══════════════════════════════════════════════════════════════════════════════

# Get external IP address
alias ip="curl -s icanhazip.com"
alias ip4="curl -s -4 icanhazip.com"
alias ip6="curl -s -6 icanhazip.com"

#═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION & DOTFILES
#═══════════════════════════════════════════════════════════════════════════════

# Reload shell config
alias src="source ~/.zshrc"
alias zs="source ~/.zshrc"

# Edit config files
alias bp="\${EDITOR:-code} ~/.zshrc"
alias kb="\${EDITOR:-code} ~/Library/KeyBindings/DefaultKeyBinding.dict"

# Chezmoi
alias cm='chezmoi'

#═══════════════════════════════════════════════════════════════════════════════
# UTILITIES
#═══════════════════════════════════════════════════════════════════════════════

# Better watch command
alias watch=viddy

# Print text right-aligned
alias right="printf '%*s' \$(tput cols)"
