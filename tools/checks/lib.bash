# shellcheck shell=bash
# Shared helpers for the Checks in tools/checks/. Sourced, not executed.
#
# Every Check accepts an optional list of files. With no files it checks every
# file in the working tree that git knows about (tracked, or untracked and not
# ignored). Each Check keeps only the files of the kind it understands, so the
# commit hook can pass every staged file to every Check.

# Checks operate on the git repo in the current directory (mise runs tasks from
# the repo root); DOTFILES_ROOT only locates this repo's scripts and cache.
DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

die() {
  printf '%s: error: %s\n' "${CHECK_NAME:-check}" "$*" >&2
  exit 1
}

require() {
  command -v "$1" >/dev/null 2>&1 || die "'$1' is required. $2"
}

# Print the kind of a file, or nothing if no Check handles it:
#   shell, shell-template, zsh, zsh-template, json, jsonc, yaml, toml
file_kind() {
  local f="$1" base first
  [[ -f "$f" ]] || return 0
  base="$(basename "$f")"

  # chezmoi always treats these as templates; they are covered by the dry-run apply.
  case "$base" in .chezmoiexternal.* | .chezmoiignore* | .chezmoiremove* | .chezmoi.*.tmpl) return 0 ;; esac

  case "$base" in
    *.sh.tmpl | *.bash.tmpl)
      echo shell-template
      return
      ;;
    *.zsh.tmpl | dot_zshrc.tmpl | dot_zshenv.tmpl | dot_zprofile.tmpl)
      echo zsh-template
      return
      ;;
    *.tmpl) return 0 ;;
    *.json)
      if is_jsonc_path "$f"; then echo jsonc; else echo json; fi
      return
      ;;
    *.jsonc)
      echo jsonc
      return
      ;;
    *.yml | *.yaml)
      echo yaml
      return
      ;;
    *.toml)
      echo toml
      return
      ;;
  esac

  # The shebang wins over the extension: some *.sh files here are zsh scripts.
  IFS= read -r first <"$f" 2>/dev/null || true
  case "$first" in
    '#!'*zsh*)
      echo zsh
      return
      ;;
    '#!'*/sh | '#!'*/sh\ * | '#!'*bash* | '#!'*dash* | '#!'*ksh* | '#!'*bats*)
      echo shell
      return
      ;;
  esac

  case "$base" in
    *.zsh | dot_zshrc | dot_zshenv | dot_zprofile | dot_zlogin | create_dot_zshrc.local) echo zsh ;;
    *.sh | *.bash | *.bats) echo shell ;;
  esac
}

# Files that are JSON with comments and trailing commas (editor settings, and
# configs whose owning app documents JSONC). Everything else must be strict JSON.
is_jsonc_path() {
  case "$1" in
    */zed/* | *Cursor/User/* | *Code/User/* | home/dot_oh-my-posh.json | .devcontainer/* | */.devcontainer/*) return 0 ;;
  esac
  return 1
}

# NUL-separated list of the files to consider: the arguments, or all known files.
candidate_files() {
  if (($#)); then
    printf '%s\0' "$@"
  else
    git ls-files -z --cached --others --exclude-standard
  fi
}

# Print, NUL-separated, the candidate files whose kind is one of the arguments
# before `--`; the files to consider follow `--`. Bash 3.2 compatible (macOS).
#   while IFS= read -r -d '' f; do files+=("$f"); done < <(select_files shell -- "$@")
select_files() {
  local kinds=" " f k
  while (($#)) && [[ "$1" != -- ]]; do
    kinds+="$1 "
    shift
  done
  [[ "${1:-}" == -- ]] && shift
  while IFS= read -r -d '' f; do
    k="$(file_kind "$f")"
    [[ -n "$k" && "$kinds" == *" $k "* ]] && printf '%s\0' "$f"
  done < <(candidate_files "$@")
  return 0
}

# Render a chezmoi template to stdout using the data of an Ephemeral machine
# (dev Role only), so the result does not depend on this Machine's own Roles
# and never needs 1Password. Nothing outside .cache/ is read or written.
render_template() {
  local file="$1" cache="$DOTFILES_ROOT/.cache/render" cfg config_tmpl
  cfg="$cache/chezmoi.yaml"
  config_tmpl="$DOTFILES_ROOT/$(cat "$DOTFILES_ROOT/.chezmoiroot")/.chezmoi.yaml.tmpl"
  mkdir -p "$cache"
  if [[ ! -s "$cfg" || "$config_tmpl" -nt "$cfg" ]]; then
    CODESPACES=true chezmoi --source "$DOTFILES_ROOT" --config "$cache/none.yaml" \
      --persistent-state "$cache/state.boltdb" --no-tty \
      execute-template --init <"$config_tmpl" >"$cfg.tmp" ||
      die "could not render $config_tmpl"
    mv "$cfg.tmp" "$cfg"
  fi
  chezmoi --source "$DOTFILES_ROOT" --config "$cfg" --persistent-state "$cache/state.boltdb" \
    --destination "$cache/home" --no-tty execute-template <"$file"
}
