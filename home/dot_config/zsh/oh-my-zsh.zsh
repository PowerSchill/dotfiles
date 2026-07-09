# Path to your oh-my-zsh installation.
export ZSH=~/.oh-my-zsh
DISABLE_AUTO_UPDATE="true"

ZSH_THEME="powerlevel10k/powerlevel10k"

################################################################################
# Oh My Zsh Plugins
################################################################################

plugins=(
  1password
  aws
  branch
  brew
  dash
  direnv
  docker
  dotenv
  extract
  forklift
  fzf
  gcloud
  gem
  gh
#  git
  git-extras
  git-flow
  gitignore
  golang
  history
  jsontools
  kubectl
  kubectx
  macos
  marked2
  pip
  pipenv
  pre-commit
  python
  shrink-path
  ssh-agent
  sublime
  sudo
  terraform
  tmux
  urltools
  vagrant
  zsh-autosuggestions
  )


# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

source $ZSH/oh-my-zsh.sh

# Avoid autosuggestions forking a completion subshell (fixes "_bat: command not found")
ZSH_AUTOSUGGEST_STRATEGY=(history match_prev_cmd)
