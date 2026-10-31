#!/usr/bin/env bash
# Check: GitHub Actions workflows are valid, using actionlint (it also lints
# the shell in `run:` steps).
set -euo pipefail
CHECK_NAME=check:workflows
# shellcheck source=tools/checks/lib.bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"
require actionlint "Run tools/bootstrap.sh to install the Toolchain."

files=()
while IFS= read -r -d '' f; do
  case "$f" in .github/workflows/*.yml | .github/workflows/*.yaml) files+=("$f") ;; esac
done < <(candidate_files "$@")
((${#files[@]})) || exit 0

actionlint "${files[@]}"
echo "$CHECK_NAME: ${#files[@]} file(s) ok"
