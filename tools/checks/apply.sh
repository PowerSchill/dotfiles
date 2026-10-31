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
count="$("${chez[@]}" managed --exclude externals 2> >(quiet) | wc -l | tr -d ' ')"
echo "$CHECK_NAME: roles '$roles' render cleanly ($count targets on $(uname -s))"
