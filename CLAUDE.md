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

| File | Purpose |
|------|---------|
| `.chezmoi.yaml.tmpl` | Master config — defines all feature flags and environment detection |
| `.chezmoiexternal.yaml` | External dependencies (Oh My Zsh, plugins, fonts, fzf-git) fetched from GitHub |
| `.chezmoidata/packages.yaml` | Package lists for all platforms/environments |
| `.chezmoitemplates/brewList.tmpl` | Conditionally formats Homebrew install lists |
| `.chezmoiignore.tmpl` | OS/environment-based file exclusions |

### Environment Detection (`.chezmoi.yaml.tmpl`)

The master template auto-detects machine context and sets boolean flags used throughout all templates:

- `ephemeral` — GitHub Codespaces, Docker, Vagrant, VMs; skips long installs and SSH config
- `headless` — SSH-only systems; skips GUI apps and fonts
- `work` — work machine (hostname/domain based)
- `personal` — personal machine (e.g., `copernicus`, `.cmschill.net` suffix)
- `shared` — machines that are both or neither
- `appearance.dark` / `appearance.light` — Catppuccin Mocha vs Latte theme variant

These flags gate what packages install, what files deploy, and how templates render.

### Package Management (`.chezmoidata/packages.yaml`)

Packages are declared in YAML, not inline scripts. The `brewList.tmpl` template reads this data and generates `~/.Brewfile` at apply time. Packages are organized by:
- **Global** — installed everywhere
- **Personal** — only on personal machines
- **Work** — only on work machines
- Ephemeral/headless machines get a reduced set

When adding a new package, edit `.chezmoidata/packages.yaml` — not the install scripts directly.

### Scripts (`.chezmoiscripts/`)

Scripts are organized by OS: `darwin/`, `linux/`, `windows/`. Key scripts:
- `run_onchange_before_install-packages.sh.tmpl` — generates and runs the Brewfile / distro package install
- `run_onchange_after_configure-dock.sh` — macOS Dock and Finder defaults
- `run_onchange_after_configure-browser.sh` — browser defaults

Scripts use `run_onchange_` so they re-run only when their content (including rendered template) changes.

### Templates

Templates use Go template syntax. Access chezmoi data with `.chezmoi.os`, `.chezmoi.arch`, and custom data via `.work`, `.personal`, `.ephemeral`, etc. The `.chezmoitemplates/` directory holds reusable partials included via `{{ template "name" . }}`.

### External Dependencies (`.chezmoiexternal.yaml`)

Oh My Zsh, plugins (zsh-autosuggestions, fast-syntax-highlighting, powerlevel10k), fzf-git, and MesloLGS NF fonts are fetched directly from GitHub releases/archives. The `read-versions-and-revisions-cache` template caches GitHub API responses for 10 minutes to avoid rate limiting.

### Appearance

Catppuccin Mocha (dark) is the default theme, applied consistently across: Zsh syntax highlighting, delta diffs, WezTerm, Alacritty, lazygit, and btop. The `appearance` variable in `.chezmoi.yaml.tmpl` controls which variant is active.
