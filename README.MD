# PowerSchill's Dotfiles

Welcome to my personal dotfiles repository! This collection is designed to quickly bootstrap a productive development environment on macOS and Linux, with a focus on modern tools, aesthetics, and efficiency.

---

## ✨ Features

- **Terminal:** [WezTerm](https://wezfurlong.org/wezterm/)
- **Shell:** [Zsh](https://www.zsh.org/) with curated plugins and themes
- **Editor:** [Neovim](https://neovim.io/) ([LazyVim](https://www.lazyvim.org/))
- **Theme:** [Catppuccin Mocha](https://catppuccin.com/)
- **Package Management:** [Homebrew](https://brew.sh/) (macOS), native package managers (Linux)
- **Automated Setup:** [chezmoi](https://www.chezmoi.io/) for dotfile management

---

## 🛠️ Prerequisites

- [Homebrew](https://brew.sh/) (macOS only)
- [Git](https://git-scm.com/)
- [chezmoi](https://www.chezmoi.io/)

---

## 🖥️ Supported Operating Systems

Tested on:
- **macOS:** Sonoma (14.x), Tahoe (26.x)
- **Fedora:** 43
- **Ubuntu:** 25.10

Other distributions may work but are not officially tested.

---

## 🚀 Quick Start

Clone and initialize your dotfiles with chezmoi:

```bash
# Install prerequisites and initialize chezmoi
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
      sudo dnf -y install git chezmoi
      ;;
    centos | rocky)
      sudo yum -y install git
      curl -sfL https://git.io/chezmoi | sh
      ;;
    amzn)
      sudo yum -y install git
      curl -sfL https://git.io/chezmoi | sh
      ;;
    debian | ubuntu)
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
