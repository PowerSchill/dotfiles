# PowerSchill's Dotfiles

Welcome to my personal dotfiles repository! This collection is designed to quickly bootstrap a productive development environment on macOS and Linux, with a focus on modern tools, aesthetics, and efficiency.

---

## ✨ Features

- **Terminal:** [WezTerm](https://wezfurlong.org/wezterm/)
- **Shell:** [Zsh](https://www.zsh.org/) with [Oh My Zsh](https://ohmyz.sh/) and curated plugins
- **Prompt:** [Powerlevel10k](https://github.com/romkatv/powerlevel10k) / [Oh My Posh](https://ohmyposh.dev/)
- **Editor:** [Neovim](https://neovim.io/) ([LazyVim](https://www.lazyvim.org/))
- **Theme:** [Catppuccin Mocha](https://catppuccin.com/) (dark) / Catppuccin Latte (light)
- **Font:** [MesloLGS NF](https://github.com/romkatv/powerlevel10k#meslo-nerd-font-patched-for-powerlevel10k) Nerd Font (installed automatically)
- **Package Management:** [Homebrew](https://brew.sh/) (macOS), native package managers (Linux)
- **Dotfile Management:** [chezmoi](https://www.chezmoi.io/)

---

## 📦 Configuration Overview

### Shell (Zsh)

Managed via `~/.zshrc` with modular configuration loaded from `~/.config/zsh/`. Key settings include:

- Extended history (10 million entries, deduplication, session sharing)
- Smart directory navigation (`AUTO_CD`, `AUTO_PUSHD`)
- Enhanced tab completion with colored output
- Automatic startup info via [fastfetch](https://github.com/fastfetch-cli/fastfetch)

**Oh My Zsh plugins (managed via `.chezmoiexternal.yaml`):**

| Plugin | Description |
|---|---|
| [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) | Fish-style command suggestions |
| [fast-syntax-highlighting](https://github.com/zdharma-continuum/fast-syntax-highlighting) | Syntax highlighting with Catppuccin Mocha theme |
| [fzf-git](https://github.com/junegunn/fzf-git.sh) | Fuzzy-search Git objects with fzf |

### Git

Git is configured in `~/.gitconfig` with:

- **Diff/merge pager:** [delta](https://github.com/dandavison/delta) with Catppuccin theme and side-by-side view
- **Aliases:** Extensive aliases via [gitalias](https://github.com/GitAlias/gitalias) plus custom shortcuts (`glog`, `fpush`, `amend`, `reword`, etc.)
- **Branch management:** [git-town](https://www.git-town.com/) integration
- **Commit template:** Standard commit message template at `~/.gitmessage`
- **Credential helper:** GitHub CLI (`gh`) when available, otherwise macOS Keychain

### Editor

- **Primary:** [Neovim](https://neovim.io/) (falls back to `vim`, `micro`, or `nano`)
- **LazyVim** configuration managed separately

### Appearance

- **Catppuccin Mocha** (dark) applied across Zsh syntax highlighting, delta diffs, and WezTerm
- **Catppuccin Latte** (light) variant supported via chezmoi `appearance` variable
- `LS_COLORS` generated with [vivid](https://github.com/sharkdp/vivid) using Catppuccin Mocha palette (macOS)

---

## 🛠️ Prerequisites

- [Git](https://git-scm.com/)
- [Homebrew](https://brew.sh/) (macOS — installed automatically by the bootstrap script if missing)
- [chezmoi](https://www.chezmoi.io/) (installed automatically by the bootstrap script)

---

## 🖥️ Supported Operating Systems

Tested on:
- **macOS:** Sonoma (14.x), Tahoe (26.x)
- **Fedora:** 43
- **Ubuntu:** 25.10

Other distributions may work but are not officially tested.

---

## 🚀 Quick Start

Run the following bootstrap script to install prerequisites and apply the dotfiles in one step:

```bash
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

chezmoi init --apply https://github.com/PowerSchill/dotfiles.git
```
