#!/usr/bin/env bash
# Check: shell scripts are formatted (style comes from .editorconfig).
#   --write   format in place instead of reporting (the `fmt` task)
# Templates are skipped: formatting their rendered output says nothing about the source.
set -euo pipefail
CHECK_NAME=check:shfmt
# shellcheck source=tools/checks/lib.bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"
require shfmt "Run tools/bootstrap.sh to install the Toolchain."

mode=(-d)
if [[ "${1:-}" == --write ]]; then
  mode=(-w)
  CHECK_NAME=fmt
  shift
fi

files=()
while IFS= read -r -d '' f; do files+=("$f"); done < <(select_files shell -- "$@")
((${#files[@]})) || exit 0

# Keep these flags in one place: they are the repo's shell style.
if shfmt "${mode[@]}" "${files[@]}"; then
  echo "$CHECK_NAME: ${#files[@]} file(s) ok"
else
  echo "$CHECK_NAME: run 'mise run fmt' to fix formatting" >&2
  exit 1
fi
