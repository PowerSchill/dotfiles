# 🏠 Dotfiles

[![CI](https://github.com/PowerSchill/dotfiles/actions/workflows/ci.yml/badge.svg)](https://github.com/PowerSchill/dotfiles/actions/workflows/ci.yml)
[![Dev container](https://github.com/PowerSchill/dotfiles/actions/workflows/devcontainer.yml/badge.svg)](https://github.com/PowerSchill/dotfiles/actions/workflows/devcontainer.yml)
[![Release](https://img.shields.io/github/v/tag/PowerSchill/dotfiles?label=release&sort=semver)](https://github.com/PowerSchill/dotfiles/tags)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

PowerSchill's personal dotfiles, managed with [chezmoi](https://www.chezmoi.io/). One command
bootstraps a development environment on macOS, Linux, Windows and WSL, configured by the Roles
you pick for each machine.

## ✨ Features

- **Role-based**: each machine is `base` plus the Roles you opt into (`dev`, `gui`, `work`,
  `personal`, `security`, `onepassword`, `homelab`). Roles are chosen once at `chezmoi init`, not
  guessed from the hostname.
- **Cross-platform**: macOS (Homebrew), Linux (apt/dnf + cargo), Windows (winget + PowerShell) and
  WSL, with every package declared in one YAML file.
- **Shell**: [Zsh](https://www.zsh.org/) with [Oh My Zsh](https://ohmyz.sh/),
  [Powerlevel10k](https://github.com/romkatv/powerlevel10k) and curated plugins; PowerShell with
  [Oh My Posh](https://ohmyposh.dev/) on Windows.
- **Terminal**: [WezTerm](https://wezfurlong.org/wezterm/) and [Ghostty](https://ghostty.org/), with
  [tmux](https://github.com/tmux/tmux).
- **Editor**: [Neovim](https://neovim.io/) with [LazyVim](https://www.lazyvim.org/).
- **Theme**: [Catppuccin](https://catppuccin.com/) Mocha (dark) or Latte (light), following the
  macOS appearance, with the [MesloLGS NF](https://github.com/romkatv/powerlevel10k#meslo-nerd-font-patched-for-powerlevel10k)
  Nerd Font installed automatically.
- **1Password integration** (optional): SSH agent, git commit signing and CLI shell plugins.
- **Ephemeral machine detection**: Codespaces, dev containers, CI runners and VMs get a lean,
  prompt-free `dev` setup.
- **Tested**: every commit runs linters, secret scanning, a dry-run apply for every Role on Linux
  and macOS, and bats tests, locally and in CI.

## 🔧 Chezmoi Variables

`home/.chezmoi.yaml.tmpl` computes these at `chezmoi init`. Templates read them as `.name`.

### User Information

- `name`: git author name
- `email`: git email. Fixed for the `personal` Role, otherwise prompted once
- `githubUsername`: GitHub account used by scripts (default `PowerSchill`)
- `gitSigningKey`, `opSshVault`, `opSshSignProgram`: SSH signing key and 1Password vault, chosen
  by the `work`/`personal` Roles
- `opShellPlugins`: CLIs wrapped by 1Password shell plugins (default `gh`, see
  [docs/1password-shell-plugins.md](docs/1password-shell-plugins.md))

### Roles

- `role.<name>`: `true`/`false` for each Role (`role.dev`, `role.security`, ...)
- `roles`: the enabled Roles as an ordered list, used to index package buckets
- `isWork`: follows the `work` Role

### Environment Detection

- `ephemeral`: `true` in CI, Codespaces, VS Code remote containers, or as `root`/`ubuntu`/`vagrant`/`vscode`
- `codespaces`: `true` in GitHub Codespaces
- `wsl`: `true` inside WSL
- `osid`: OS plus distribution, e.g. `darwin`, `linux-fedora`, `linux-ubuntu`
- `uname_arch`: CPU architecture on Linux (`x86_64`, `arm64`)
- `hostname`: on macOS the stable `ComputerName`
- `appearance`: `dark` or `light`, from the macOS system setting

### Windows Enterprise (Windows and WSL)

Read from `dsregcmd /status` (through interop in WSL). Elsewhere every flag is `false`.

- `isEntraIDJoined`: device is Entra ID (Azure AD) joined
- `isEntraRegistered`: device is Entra registered (workplace joined)
- `isADDomainJoined`: device is joined to an AD domain
- `isIntuneJoined`: device is MDM (Intune) enrolled
- `entraIDTenantName`, `entraIDTenantId`: the Entra tenant, when joined

## 📁 Structure

```
.
├── .devcontainer/            # dev container image (ghcr.io/powerschill/dotfiles-dev)
├── .github/workflows/        # CI (validate, dry-run apply per Role, WSL) and image publishing
├── docs/
│   ├── adr/                  # architecture decision records
│   └── 1password-shell-plugins.md
├── home/                     # chezmoi source root (.chezmoiroot)
│   ├── .chezmoi.yaml.tmpl    # Roles, environment detection, identity
│   ├── .chezmoidata/         # packages.yaml: packages per platform, base + one bucket per Role
│   ├── .chezmoiexternal.yaml # Oh My Zsh, plugins, fonts and themes fetched from GitHub
│   ├── .chezmoiscripts/      # install and configure scripts for darwin, linux and windows
│   ├── .chezmoitemplates/    # shared template partials
│   ├── dot_config/           # ~/.config: zsh, git, nvim, wezterm, ghostty, ...
│   └── install.sh / .ps1     # pinned chezmoi + init --apply from a clone
├── tests/                    # bats unit tests and one acceptance test per requirement
├── tools/                    # bootstrap, Checks, git hooks and helpers for working on the repo
├── mise.toml                 # the repo Toolchain and every task (mise.full.toml adds extras)
├── GLOSSARY.md               # Roles, Profiles, Toolchain, Checks and other terms
└── install.sh / install.ps1  # wrappers for Coder and other "run install.sh" hosts
```

## 🚀 Quick Start

### Install on macOS

Install [Homebrew](https://brew.sh/) if needed, then chezmoi, then apply:

```bash
command -v brew >/dev/null || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"
brew install git chezmoi
chezmoi init --apply PowerSchill
```

### Install on Linux

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin" init --apply PowerSchill
```

Or from a clone, which installs the pinned chezmoi version first:

```bash
git clone https://github.com/PowerSchill/dotfiles.git ~/.local/share/chezmoi
~/.local/share/chezmoi/install.sh
```

Tested on Fedora 43 and Ubuntu 25.10. Other distributions may work.

### Install on Windows (PowerShell)

**Option 1: winget**

```powershell
winget install --id Git.Git -e
winget install --id twpayne.chezmoi -e
chezmoi init --apply PowerSchill
```

**Option 2: from a clone**

```powershell
git clone https://github.com/PowerSchill/dotfiles.git $HOME\.local\share\chezmoi
& $HOME\.local\share\chezmoi\install.ps1
```

### Install on WSL

Use the Linux instructions inside your distribution. Enterprise enrollment of the Windows host is
detected through interop (see [Windows Enterprise](#windows-enterprise-windows-and-wsl)).

### What Happens on First Run

1. **Role prompts**: a yes/no question for each Role. Answers are saved and not asked again.
2. **Email prompt**: once, unless the `personal` Role is on.
3. **Packages**: `base` plus every enabled Role's bucket is installed (`brew bundle`, apt/dnf/cargo,
   or winget).
4. **Externals**: Oh My Zsh, Powerlevel10k, Zsh plugins, fzf-git, gitalias, Catppuccin themes and
   fonts are fetched from GitHub.
5. **OS defaults**: on macOS, Dock, Finder and browser defaults are applied.

Ephemeral machines skip the prompts and get the `dev` Role only. Non-interactive runs elsewhere use
the defaults (`dev` and `gui` on).

### Development Container

The repo ships a dev container with the Toolchain, zsh and these dotfiles already applied.

- 📦 **Image**: `ghcr.io/powerschill/dotfiles-dev`, multi-arch (amd64, arm64), published from
  `main` (`latest`) and from each release tag
- 🐚 **Shell**: zsh with the Ephemeral (`dev`) configuration applied
- 🧰 **Toolchain**: pinned mise tools (chezmoi, shellcheck, shfmt, gitleaks, bats, ...)
- 🔄 **Setup**: `tools/bootstrap.sh` runs on create, so `mise run check` works immediately

Open this repo in VS Code or Codespaces and choose **Reopen in Container**. To reuse the image in
another project:

```json
{
  "image": "ghcr.io/powerschill/dotfiles-dev:latest"
}
```

## 🎭 Customization

### Roles

| Role | Default | Enables |
|---|---|---|
| `dev` | on | Languages, runtimes, build tooling, linters, git tooling |
| `gui` | on | Casks, fonts, macOS desktop helper CLIs |
| `work` | off | Work machine (git email is prompted) |
| `personal` | off | Personal git identity, personal apps |
| `security` | off | Security and pentesting tools (nmap, burp-suite, trivy, tfsec, checkov) |
| `onepassword` | off | 1Password SSH agent, git commit signing, and `gh` credential helper |
| `homelab` | off | kubectl, minikube, terraform, docker, cloud CLIs, network tools |

Without `onepassword`, credentials fall back to the system: `ssh-agent`, `ssh-keygen` signing, and
Keychain (macOS) or the git `cache` helper (Linux).

```bash
cmrole list               # show enabled Roles
cmrole add security       # enable a Role and re-apply
cmrole remove onepassword # disable a Role and re-apply
```

### Personal Information

```bash
# Re-answer the prompts (email and Roles)
chezmoi init --data=false
```

Per-machine overrides (`githubUsername`, `opShellPlugins`, `opCopilotEnvironmentId`) go in the
`data:` section of your local `~/.config/chezmoi/chezmoi.yaml`. Shell tweaks for one machine go in
`~/.zshrc.local`, which is created once and never overwritten.

### Packages

Add packages to `home/.chezmoidata/packages.yaml` under the right platform and bucket (`base` or a
Role), not to the install scripts.

## 📝 Common Commands

```bash
# Preview what would change
chezmoi diff

# Apply changes
chezmoi apply

# Edit a managed file, then apply it
chezmoi edit ~/.zshrc

# Copy a file changed in your home directory back into the source
chezmoi re-add ~/.zshrc

# Pull the repo and refresh externals (plugins, fonts, themes)
chezmoi update
```

> **Note:** `autoCommit` and `autoPush` are on, so `chezmoi edit` and `re-add` commit and push to
> `origin` automatically, with Conventional Commit messages such as `chore(chezmoi): update .zshrc`.

### Handy Shell Functions

- `cmrole`: list, add or remove Roles
- `theme-sync`: re-sync the Catppuccin variant with the macOS appearance and re-apply
- `gcm [-y]`: generate a commit message for the staged diff with Claude

## 🛠 Development Tools

### Toolchain (mise)

The tools for working *on* the repo are pinned in `mise.toml`, separate from the packages the
dotfiles install. [Renovate](renovate.json) keeps them current.

```bash
# Once per checkout: pinned mise, the Toolchain, and the git hooks
tools/bootstrap.sh

# Show the Profile, Roles and tool versions
mise run info
```

### Tasks

```bash
# List every task with a description
mise tasks

# Checks the commit hook runs (syntax, shellcheck, shfmt, zsh, secrets, private info, ...)
mise run check

# Everything CI runs: Checks, whole-repo scan, commit messages, dry-run apply, tests
mise run validate

# Dry-run apply for a Role set into a scratch home
mise run check:apply --roles dev,gui

# Unit tests, and one acceptance test per requirement (needs Docker)
mise run test
mise run test:acceptance

# Read-only diff against your home, then apply (refuses without --yes)
mise run preview
mise run apply --yes

# Format shell scripts (shfmt -i 2 -ci)
mise run fmt

# Release notes since the last tag, printed only
mise run release:preview
```

### Profiles

- **minimal**: what CI and the hooks need. Chosen automatically in CI, containers and Codespaces.
- **full**: adds git-cliff, act, node and the devcontainer CLI. Chosen on workstations.

Override with `DOTFILES_PROFILE=minimal tools/bootstrap.sh`. The choice is recorded in the
untracked `.miserc.local.toml`.

### Git Hooks and Commits

`mise run hooks:install` (run by bootstrap) adds pre-commit, commit-msg and pre-push hooks that call
the same `check:*` tasks as CI, through mise, so they work without python3 or mise on `PATH`.

- 🔐 Secrets: gitleaks on staged changes and on pushed commits
- 🕵️ Private info: key files, foreign home paths, unexpected emails, and a local, untracked denylist
- 🐚 Shell: shellcheck and shfmt, with templates rendered for every Role first
- 📝 Commits: [Conventional Commits](https://www.conventionalcommits.org/) (`feat`, `fix`, `perf`,
  `refactor`, `docs`, `test`, `ci`, `chore`, `revert`), e.g. `fix(zsh): quote PATH`

Releases are date tags such as `v2026.10.31`, created by hand.

## 📚 Learn More

- [chezmoi documentation](https://www.chezmoi.io/)
- [mise documentation](https://mise.jdx.dev/)
- [GLOSSARY.md](GLOSSARY.md): the terms used in this repo
- [docs/adr/](docs/adr/): why the tooling works the way it does

## 🤝 Contributing

These are personal dotfiles, but feel free to fork them and adapt them to your own machines.

## 📄 License

[MIT](LICENSE)
