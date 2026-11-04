#!/usr/bin/env bash
# Check: every Homebrew entry in packages.yaml uses a known type, bucket, option
# and platform. Without files it checks home/.chezmoidata/packages.yaml; with
# files it checks those named packages.yaml and ignores the rest.
set -euo pipefail
CHECK_NAME=check:packages
# shellcheck source=tools/checks/lib.bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"
require yq "Run tools/bootstrap.sh to install the Toolchain."
require python3 "Run tools/bootstrap.sh to install the Toolchain."

source_dir="$DOTFILES_ROOT/$(cat "$DOTFILES_ROOT/.chezmoiroot")"
files=()
if (($#)); then
  for f in "$@"; do
    if [[ "$(basename "$f")" == packages.yaml ]]; then files+=("$f"); fi
  done
else
  files=("$source_dir/.chezmoidata/packages.yaml")
fi

status=0
for f in ${files[@]+"${files[@]}"}; do
  yq -o json '.' "$f" |
    python3 -I "$DOTFILES_ROOT/tools/checks/packages.py" "$f" "$source_dir/.chezmoi.yaml.tmpl" || status=1
done
((status == 0)) && echo "$CHECK_NAME: ${#files[@]} file(s) ok"
exit "$status"
