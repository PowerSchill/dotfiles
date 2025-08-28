#!/bin/bash
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
    ;;
  amzn)
    echo "Distribution is Amazon Linux"
    sudo yum -y install git
    ;;
  debian | ubuntu)
    echo "Distribution is Debian"
    if ! command -v brew &>/dev/null; then
      sudo apt-get -y install git
    fi
    ;;
  *)
    echo "Unable to identify OS distribution - $ID"

    exit
    ;;
  esac

  # Install chezmoi
  curl -sfL https://git.io/chezmoi | sh

fi

export PATH=$HOME/bin:$PATH
chezmoi init --apply --verbose git@github.com:PowerSchill/dotfiles.git
