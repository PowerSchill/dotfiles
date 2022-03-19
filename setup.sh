#!/bin/bash

cd "$HOME" || return
system_type = $(uname -s)

if [[ $system_type == "Darwin"]]; then
  echo "Hello Mac User!"
  echo "Installing Hombebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> /Users/powerschill/.zprofile
  eval "$(/opt/homebrew/bin/brew shellenv)"

  brew install git

  # Install Chezmoi
  brew install chezmoi
fi

if [[ $system_type == "Linux"]]
  echo "Hello Linux User!"
  sudo yum update #TODO: Handle Ubuntu
  sudo yum -y install git

  # Install chezmoi
  curl -sfL https://git.io/chezmoi | sh
fi


ssh_key=~/.ssh/id_rsa
if [ -f "$ssh_key" ]; then

else
  ssh-keygen -t ed25519 -C "Mark.Schill@cmschill.net" -f $ssh_key
fi

brew install gh
gh auth login

export PATH=$HOME/bin:$PATH
chezmoi init --apply --verbose git@github.com:PowerSchill/dotfiles.git

