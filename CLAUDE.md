# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

Personal dotfiles managed by [chezmoi](https://www.chezmoi.io/), targeting macOS (primary), Linux (Fedora/Ubuntu), and Windows. The repo bootstraps a full dev environment with Zsh + Oh My Zsh, Neovim (LazyVim), WezTerm, Catppuccin theming, and 100+ CLI tools.

## Common Commands

```bash
# Apply all changes to the home directory
chezmoi apply

# Apply a single file
chezmoi apply ~/.zshrc

# Preview what would change (dry run)
chezmoi diff

# Re-run a changed script manually
chezmoi apply --force

# Edit a managed file (opens in $EDITOR, then applies)
chezmoi edit ~/.zshrc

# Re-add a modified file from home dir back into chezmoi source
chezmoi re-add ~/.zshrc

# Check template rendering for a file
chezmoi execute-template < .chezmoi.yaml.tmpl

# Update all external dependencies (oh-my-zsh, plugins, fonts)
chezmoi update
```

There are no build/test/lint commands — this is a configuration repo, not a software project.

## Architecture

### chezmoi File Naming Conventions

chezmoi uses filename prefixes to determine target behavior:
- `dot_` → becomes `.` (e.g., `dot_zshrc` → `~/.zshrc`)
- `private_` → files with restricted permissions (600/700)
- `dot_config/` → maps to `~/.config/`
- `run_once_` → script runs once ever
- `run_onchange_` → script runs when content changes
- `run_onchange_before_` / `run_onchange_after_` → ordering
- `.tmpl` suffix → Go template, rendered with chezmoi data before applying

### Key Files

`.chezmoiroot` sets the source root to `home/`, so every chezmoi-managed file lives under `home/`.
Only `README.MD`, `CLAUDE.md`, and repo tooling sit at the top level.

| File | Purpose |
|------|---------|
| `home/.chezmoi.yaml.tmpl` | Master config — defines all feature flags and environment detection |
| `home/.chezmoiexternal.yaml` | External dependencies (Oh My Zsh, plugins, fonts, fzf-git) fetched from GitHub |
| `home/.chezmoidata/packages.yaml` | Package lists for all platforms/environments |
| `home/.chezmoitemplates/brewList.tmpl` | Conditionally formats Homebrew install lists |
| `home/.chezmoiignore.tmpl` | OS/environment-based file exclusions |

### Roles (`home/.chezmoi.yaml.tmpl`)

A machine's configuration is **role-based**. Roles are opt-in capabilities, chosen once at
`chezmoi init` (via `promptBoolOnce`) and persisted in chezmoi's state, so they do not depend on
network-visible hostname/FQDN detection.

| Role | Enables |
|------|---------|
| `dev` | Languages, runtimes, build tooling, linters, git tooling |
| `gui` | Casks, fonts, macOS desktop helper CLIs |
| `work` | Work machine (git email is prompted, not hard-coded) |
| `personal` | Personal git identity, personal apps, extra statusline row |
| `security` | Security and pentesting tools (nmap, burp-suite, trivy, tfsec, checkov) |
| `onepassword` | 1Password as credential backend: SSH agent, git signing, credential helper |
| `homelab` | kubectl, minikube, terraform, docker, cloud CLIs, network tools |

Templates branch on `.role.<name>` (e.g. `{{ if .role.security }}`) and iterate `.roles` (an
ordered list) to index into package buckets.

Two things are **not** roles:
- `ephemeral` — auto-detected (Codespaces, containers, VMs). Machine lifetime, not capability;
  it is force-set by environment detection rather than chosen. Ephemeral machines get `dev` only.
- `appearance` — `dark` / `light`, from the macOS system setting.

Change a machine's roles with the `cmrole` shell function (`home/dot_config/zsh/functions/role.zsh`):

```bash
cmrole list              # show enabled roles
cmrole add security      # enable and re-apply
cmrole remove onepassword
```

It drives `chezmoi init --promptBool "<role>=true|false"`. Note chezmoi keys `--promptBool` on the
*prompt string*, which is why `home/.chezmoi.yaml.tmpl` uses the bare role name as the prompt text.

When `onepassword` is off, credential handling falls back to system-native: system `ssh-agent`,
git's default `ssh-keygen` signer, and `osxkeychain` (darwin) / `cache` (linux) for git credentials.

### Package Management (`home/.chezmoidata/packages.yaml`)

Packages are declared in YAML, not inline scripts. The `brewList.tmpl` template reads this data and
generates `~/.Brewfile` at apply time. Packages are bucketed by role:

- **`base`** — installed on every machine, including ephemeral ones
- **one bucket per role** — appended only when that role is enabled

Buckets exist for all three platforms (darwin, linux debian/fedora, windows winget), so a role means
the same thing everywhere. Buckets may be empty or absent — the install scripts `range` over an
`index` result, and ranging over a missing key is a no-op.

Individual darwin entries may set `excludeEphemeral: true` to be skipped on throwaway machines, and
`args:` (e.g. `appdir`) which is emitted into the Brewfile.

When adding a new package, edit `home/.chezmoidata/packages.yaml` — not the install scripts directly.

### Scripts (`home/.chezmoiscripts/`)

Scripts are organized by OS: `darwin/`, `linux/`, `windows/`. Key scripts:
- `darwin/run_onchange_before_install-packages.sh.tmpl` — generates `~/.Brewfile` and runs `brew bundle`
- `linux/run_onchange_before_10_install-packages.sh.tmpl` — apt/dnf and cargo package install
- `windows/run_onchange_windows-install-packages.ps1.tmpl` — winget package install
- `darwin/run_onchange_after_configure-dock.sh` — macOS Dock and Finder defaults
- `darwin/run_onchange_after_configure-browser.sh` — browser defaults

Scripts use `run_onchange_` so they re-run only when their content (including rendered template) changes.

### Templates

Templates use Go template syntax. Access chezmoi data with `.chezmoi.os`, `.chezmoi.arch`, and custom data via `.role.<name>`, `.roles`, `.ephemeral`, `.appearance`, etc. The `home/.chezmoitemplates/` directory holds reusable partials included via `{{ template "name" . }}`.

### External Dependencies (`home/.chezmoiexternal.yaml`)

Oh My Zsh, plugins (zsh-autosuggestions, fast-syntax-highlighting, powerlevel10k), fzf-git, and MesloLGS NF fonts are fetched directly from GitHub releases/archives. The `read-versions-and-revisions-cache` template caches GitHub API responses for 10 minutes to avoid rate limiting.

### Appearance

Catppuccin Mocha (dark) is the default theme, applied consistently across: Zsh syntax highlighting, delta diffs, WezTerm, Ghostty, lazygit, and btop. The `appearance` variable in `home/.chezmoi.yaml.tmpl` controls which variant is active.
