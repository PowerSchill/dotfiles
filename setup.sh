#!/bin/bash

cd "$HOME" || return
system_type=$(uname -s)

if [[ $system_type == "Darwin" ]]; then
  echo "Hello Mac User!"
  echo "Installing Hombebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> /Users/powerschill/.zprofile
  eval "$(/opt/homebrew/bin/brew shellenv)"

  brew install git

  # Install Chezmoi
  brew install chezmoi

elif [[ $system_type == "Linux" ]]; then

    . /etc/os-release

    case $ID in
      centos)
        echo "Distribution is CentOS"
        sudo yum -y install git

        sudo dnf install 'dnf-command(config-manager)'
        sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
        sudo dnf -y install gh
        ;;
      *)
        echo "Unable to identify OS distribution"
        exit
        ;;
    esac


    # distribution=$(lsb_release -i | cut -f 2-)

    # if [[ $distribution == "Ubuntu" ||  $distribution == "Raspbian"  ]]; then
    #     sudo apt-get update
    #     sudo apt-get -y install git curl

    #     # Install GitHub CLI
    #     curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    #     echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    #     sudo apt update
    #     sudo apt install gh


    # Install chezmoi
    curl -sfL https://git.io/chezmoi | sh
fi


ssh-keygen -f ~/.ssh/github.key -N "" -q

gh auth login --git-protocol ssh

export PATH=$HOME/bin:$PATH
chezmoi init --apply --verbose git@github.com:PowerSchill/dotfiles.git

