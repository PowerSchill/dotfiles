# PowerSchill's Dotfiles

Welcome to my personal dotfiles repository! This collection is designed to quickly bootstrap a productive development environment on macOS, Linux, and Windows, with a focus on modern tools, aesthetics, and efficiency.

---

## ✨ Features

- **Terminal:** [WezTerm](https://wezfurlong.org/wezterm/) and [Ghostty](https://ghostty.org/), with [tmux](https://github.com/tmux/tmux)
- **Shell:** [Zsh](https://www.zsh.org/) with [Oh My Zsh](https://ohmyz.sh/) and curated plugins (PowerShell on Windows)
- **Prompt:** [Powerlevel10k](https://github.com/romkatv/powerlevel10k) / [Oh My Posh](https://ohmyposh.dev/)
- **Editor:** [Neovim](https://neovim.io/) ([LazyVim](https://www.lazyvim.org/))
- **Theme:** [Catppuccin Mocha](https://catppuccin.com/) (dark) / Catppuccin Latte (light), following the system appearance
- **Font:** [MesloLGS NF](https://github.com/romkatv/powerlevel10k#meslo-nerd-font-patched-for-powerlevel10k) Nerd Font (installed automatically)
- **Package Management:** [Homebrew](https://brew.sh/) (macOS), apt/dnf + cargo (Linux), winget (Windows), all declared in one YAML file
- **Dotfile Management:** [chezmoi](https://www.chezmoi.io/), with role-based machine configuration

---

## 🛠️ Prerequisites

- [Git](https://git-scm.com/)
- [chezmoi](https://www.chezmoi.io/)
- [Homebrew](https://brew.sh/) (macOS only)

The Quick Start script below installs all of these if they are missing.

---

## 🖥️ Supported Operating Systems

Tested on:
- **macOS:** Sonoma (14.x), Tahoe (26.x)
- **Fedora:** 43
- **Ubuntu:** 25.10

Windows is supported via winget and PowerShell. Other distributions may work but are not officially tested.

---

## 🚀 Quick Start

### macOS / Linux

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
    debian | ubuntu)
      sudo apt-get update
      sudo apt-get -y install git curl
      sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
      export PATH="$HOME/.local/bin:$PATH"
      ;;
    *)
      echo "Unable to identify OS distribution - $ID"
      exit 1
      ;;
  esac
fi

chezmoi init --apply https://github.com/PowerSchill/dotfiles.git
```

### Windows (PowerShell)

```powershell
winget install --id Git.Git -e
winget install --id twpayne.chezmoi -e
chezmoi init --apply https://github.com/PowerSchill/dotfiles.git
```

### What happens on first run

1. **Role prompts.** `chezmoi init` asks a yes/no question for each [role](#-roles) (`dev`, `gui`, `work`, `personal`, `security`, `onepassword`, `homelab`). Answers are saved and not asked again.
2. **Email prompt.** Unless the `personal` role is enabled, you are asked once for a git email address.
3. **Packages.** The OS install script builds the package list from `base` plus every enabled role and installs it (`~/.Brewfile` + `brew bundle` on macOS, apt/dnf/cargo on Linux, winget on Windows).
4. **Externals.** Oh My Zsh, Powerlevel10k, Zsh plugins, fzf-git, gitalias, Catppuccin themes, and MesloLGS NF fonts are fetched from GitHub.
5. **OS defaults.** On macOS, Dock, Finder, and browser defaults are applied.

Ephemeral machines (Codespaces, dev containers, Vagrant/Multipass VMs, or when running as `root`/`ubuntu`/`vagrant`/`vscode`) are detected automatically: they skip the prompts and get the `dev` role only. Non-interactive runs on other machines use the role defaults (`dev` and `gui` on).

---

## 🎭 Roles

A machine's configuration is `base` plus one opt-in bucket per enabled role.

| Role | Default | Enables |
|---|---|---|
| `dev` | on | Languages, runtimes, build tooling, linters, git tooling |
| `gui` | on | Casks, fonts, macOS desktop helper CLIs |
| `work` | off | Work machine (git email is prompted) |
| `personal` | off | Personal git identity, personal apps |
| `security` | off | Security and pentesting tools (nmap, burp-suite, trivy, tfsec, checkov) |
| `onepassword` | off | 1Password SSH agent, git commit signing, and `gh` credential helper |
| `homelab` | off | kubectl, minikube, terraform, docker, cloud CLIs, network tools |

Change roles later with the `cmrole` shell function:

```bash
cmrole list               # show enabled roles
cmrole add security       # enable a role and re-apply
cmrole remove onepassword # disable a role and re-apply
```

---

## 📦 Configuration Overview

### Shell (Zsh)

Managed via `~/.zshrc` with modular configuration loaded from `~/.config/zsh/*.zsh` and `~/.config/zsh/functions/*.zsh`. Key settings include:

- Extended history (10 million entries, deduplication, session sharing)
- Smart directory navigation (`AUTO_CD`, `AUTO_PUSHD`)
- Case-insensitive, colored tab completion with a cached `compinit`
- Automatic startup info via [fastfetch](https://github.com/fastfetch-cli/fastfetch)
- Machine-specific overrides in `~/.zshrc.local` (created once, never overwritten)

**Externally managed plugins (`.chezmoiexternal.yaml`):**

| Plugin | Description |
|---|---|
| [powerlevel10k](https://github.com/romkatv/powerlevel10k) | Zsh prompt theme |
| [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) | Fish-style command suggestions |
| [fast-syntax-highlighting](https://github.com/zdharma-continuum/fast-syntax-highlighting) | Syntax highlighting with Catppuccin theme |
| [fzf-git](https://github.com/junegunn/fzf-git.sh) | Fuzzy-search Git objects with fzf |

**Handy functions:**

| Function | Description |
|---|---|
| `cmrole` | List, add, or remove chezmoi roles |
| `theme-sync` | Re-sync the Catppuccin variant with the current macOS appearance and re-apply |
| `gcm [-y]` | Generate a commit message for the staged diff with Claude |

### Git

Git is configured in `~/.config/git/config` with:

- **Diff/merge pager:** [delta](https://github.com/dandavison/delta) with Catppuccin theme and side-by-side view
- **Aliases:** [gitalias](https://github.com/GitAlias/gitalias) plus custom shortcuts (`glog`, `fpush`, `amend`, `reword`, `undo`, etc.)
- **Branch management:** [git-town](https://www.git-town.com/) integration (`hack`, `sync`, `propose`, ...)
- **Commit template:** `~/.config/git/message`
- **Pull:** fast-forward only with rebase; `rerere` enabled
- **Credentials:** with the `onepassword` role, `gh` via the 1Password CLI plugin and SSH signing via `op-ssh-sign`; otherwise macOS Keychain (`osxkeychain`) or the git `cache` helper on Linux
- **Diff tool:** Kaleidoscope (`ksdiff`) when installed

### Editor

- **Primary:** [Neovim](https://neovim.io/) with [LazyVim](https://www.lazyvim.org/) (`~/.config/nvim`)
- `$EDITOR` falls back to `vim`, `micro`, or `nano`

### Appearance

- **Catppuccin Mocha** (dark) / **Catppuccin Latte** (light) applied across Zsh syntax highlighting, delta, WezTerm, Ghostty, lazygit, btop, and more
- The variant follows the macOS system appearance at apply time; run `theme-sync` after switching
- `LS_COLORS` generated with [vivid](https://github.com/sharkdp/vivid) (macOS)

---

## 🗂️ Repository Layout

`.chezmoiroot` points chezmoi at `home/`, so everything that gets applied lives there.

| Path | Purpose |
|---|---|
| `home/.chezmoi.yaml.tmpl` | Master config: roles, environment detection, appearance, identity |
| `home/.chezmoidata/packages.yaml` | Package lists per platform, bucketed by `base` and role |
| `home/.chezmoiexternal.yaml` | Externals fetched from GitHub (Oh My Zsh, plugins, fonts, themes) |
| `home/.chezmoiscripts/{darwin,linux,windows}/` | Per-OS install and configuration scripts |
| `home/.chezmoitemplates/` | Shared template partials (e.g. `brewList.tmpl`) |
| `home/.chezmoiignore` | OS-, role-, and environment-based exclusions |

To add a package, edit `home/.chezmoidata/packages.yaml` under the right platform and bucket. Do not edit the install scripts directly.

---

## 🔧 Day-to-Day

```bash
chezmoi diff          # preview changes
chezmoi apply         # apply changes
chezmoi edit ~/.zshrc # edit a managed file
chezmoi re-add ~/.zshrc # pull a changed file back into the source
chezmoi update        # pull the repo and refresh externals
```

> **Note:** `autoCommit` and `autoPush` are enabled, so `chezmoi edit`/`re-add` commit and push to `origin` automatically.

---

## 🧰 Working on This Repo

The tools for working on the repo (linters, tests, chezmoi itself) are pinned in `mise.toml`, separate from the packages the dotfiles install.

```bash
tools/bootstrap.sh     # once per checkout: installs pinned mise and the Toolchain, plus git hooks
mise tasks             # list every chore
mise run check         # what the commit hook runs
mise run validate      # what CI runs
mise run preview       # see what applying would change (read-only)
mise run apply --yes   # apply (refuses without --yes)
```

- **Commit messages** follow [Conventional Commits](https://www.conventionalcommits.org/): `feat`, `fix`, `perf`, `refactor`, `docs`, `test`, `ci`, `chore` or `revert`, with an optional scope, e.g. `fix(zsh): quote PATH`.
- **Dev container:** this repo opens in `.devcontainer/`, and other projects can reuse the image with `"image": "ghcr.io/powerschill/dotfiles-dev:latest"` in their `devcontainer.json`.
- **Terms and decisions:** [`GLOSSARY.md`](GLOSSARY.md) defines Roles, Profiles, the Toolchain and Checks; [`docs/adr/`](docs/adr/) records why.
