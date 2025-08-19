#!/bin/bash

cd "$HOME" || return
system_type=$(uname -s)

if [[ $system_type == "Darwin" ]]; then
  if ! command -v brew &>/dev/null; then
    echo "Homebrew is not installed. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >>/Users/powerschill/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
  else
    echo "Homebrew is already installed."
  fi

  brew install git chezmoi

elif [[ $system_type == "Linux" ]]; then

  . /etc/os-release

  case $ID in
  centos | rocky)
    echo "Distribution is CentOS"
    sudo yum -y install git

    sudo dnf install 'dnf-command(config-manager)'
    sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
    sudo dnf -y install gh
    ;;
  amzn)
    echo "Distribution is Amazon Linux"
    sudo yum -y install git

    sudo yum-config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
    sudo yum -y install gh
    ;;
  debian | ubuntu)
    echo "Distribution is Debian"
    sudo apt-get update
    sudo apt-get -y install git curl

    # Install GitHub CLI
    (type -p wget >/dev/null || (sudo apt update && sudo apt-get install wget -y)) &&
      sudo mkdir -p -m 755 /etc/apt/keyrings &&
      wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null &&
      sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg &&
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null &&
      sudo apt update &&
      sudo apt install gh -y
    ;;
  *)
    echo "Unable to identify OS distribution"

    exit
    ;;
  esac

  # Install chezmoi
  curl -sfL https://git.io/chezmoi | sh
fi

export PATH=$HOME/bin:$PATH
chezmoi init --apply --verbose git@github.com:PowerSchill/dotfiles.git
