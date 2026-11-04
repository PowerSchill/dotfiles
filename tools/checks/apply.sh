#!/usr/bin/env bash
# Check: Dry-run apply. Render every target and script for a synthetic Machine
# into a scratch home directory, without writing it or running scripts.
#
#   apply.sh [<roles>]   `ephemeral` (default) or a comma-separated Role list
#
# Externals are not cloned (their config is still rendered). GitHub API
# responses are cached in .cache/chezmoi so repeat runs make few requests.
set -euo pipefail
CHECK_NAME=check:apply
# shellcheck source=tools/checks/lib.bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"
require chezmoi "Run tools/bootstrap.sh to install the Toolchain."
require yq "Run tools/bootstrap.sh to install the Toolchain."

roles="${1:-ephemeral}"
work="$DOTFILES_ROOT/.cache/apply/${roles//,/-}"
rm -rf "$work"
mkdir -p "$work/home"
cfg="$("$DOTFILES_ROOT/tools/bin/dotfiles-role-config" "$roles" "$work")"

chez=(chezmoi --source "$DOTFILES_ROOT" --config "$cfg" --destination "$work/home"
  --persistent-state "$work/state.boltdb" --cache "$DOTFILES_ROOT/.cache/chezmoi" --no-tty)

# The config is generated rather than produced by `chezmoi init`, so chezmoi warns
# that its template changed; that warning is expected here.
quiet() { grep -v 'config file template has changed' >&2 || true; }

if ! "${chez[@]}" apply --dry-run --exclude externals 2> >(quiet); then
  die "dry-run apply failed for roles '$roles' (see above)"
fi
if [[ -n "$(find "$work/home" -mindepth 1 -print -quit)" ]]; then
  die "dry-run apply wrote into the scratch home; it must not write anything"
fi

# Homebrew reads the Brewfile as Ruby, so only Homebrew can prove it parses. It is
# not part of the Toolchain: CI's runners carry it, the dev container does not.
find_brew() {
  local candidate
  for candidate in "${DOTFILES_BREW:-}" "$(command -v brew || true)" /opt/homebrew/bin/brew \
    /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
    [[ -x "$candidate" ]] && echo "$candidate" && return 0
  done
  return 1
}

parsed=""
# Homebrew refuses root outside a container, and CI's root container has no brew.
if { [[ -n "${DOTFILES_BREW:-}" ]] || [[ "$(id -u)" != 0 ]]; } && brew_bin="$(find_brew)"; then
  brewfile="$work/Brewfile"
  # shellcheck disable=SC2016 # a chezmoi template, not a shell expression
  "${chez[@]}" execute-template '{{ template "brewfile.tmpl" . }}' >"$brewfile" 2> >(quiet) ||
    die "could not render the Brewfile for roles '$roles'"
  if ! HOMEBREW_NO_AUTO_UPDATE=1 "$brew_bin" bundle list --file="$brewfile" >/dev/null; then
    die "Homebrew could not parse the Brewfile for roles '$roles' ($brewfile)"
  fi
  parsed=", Homebrew parsed the Brewfile"
fi

count="$("${chez[@]}" managed --exclude externals 2> >(quiet) | wc -l | tr -d ' ')"
echo "$CHECK_NAME: roles '$roles' render cleanly ($count targets on $(uname -s)$parsed)"
