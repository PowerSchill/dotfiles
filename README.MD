# PowerSchill's Dotfiles

A curated collection of configuration files to set up a productive development environment on macOS and Linux.

## Features

- **Terminal**: wezterm
- **Shell**: zsh
- **Editor**: neovim ([LazyVim](https://www.lazyvim.org/))
- **Theme**: catppuccin mocha

## Prerequisites

- [Homebrew](https://brew.sh/) (macOS)
- [Git](https://git-scm.com/)
- [chezmoi](https://www.chezmoi.io/)

## Supported Operating Systems

The following operating systems have been tested. Other flavors and versions are probably functional but have not been tested.

- macOS
  - Tahoe (26.x)
- Fedora
  - v43
- Ubuntu
  - 25.10

## Getting Started

Clone and initialize your dotfiles with chezmoi:

```shell
#!/bin/bash
system_type=$(uname)

if [[ $system_type == "Darwin" ]]; then
  if ! command -v brew &>/dev/null; then
    echo "Homebrew is not installed. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
    eval "$(/opt/homebrew/bin/brew shellenv)"
  else
    echo "Homebrew is already installed."
  fi

  brew install git chezmoi

elif [[ $system_type == "Linux" ]]; then
  . /etc/os-release

  case $ID in
  fedora)
      echo "Distribution is Fedora"
    sudo dnf -y install git chezmoi
    ;;
  centos | rocky)
      echo "Distribution is CentOS/Rocky"
    sudo yum -y install git
    curl -sfL https://git.io/chezmoi | sh
    ;;
  amzn)
    echo "Distribution is Amazon Linux"
    sudo yum -y install git
    curl -sfL https://git.io/chezmoi | sh
    ;;
  debian | ubuntu)
      echo "Distribution is Debian/Ubuntu"
      sudo apt-get -y install git
      snap install chezmoi --classic
    ;;
  *)
    echo "Unable to identify OS distribution - $ID"
      exit 1
    ;;
  esac
fi

chezmoi init --verbose https://github.com/PowerSchill/dotfiles.git
```
