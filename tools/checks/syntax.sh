#!/usr/bin/env bash
# Check: config files parse. YAML with yq; JSON, JSONC and TOML with Python's
# standard library (offline: no schema downloads). Templates are covered by
# the dry-run apply instead.
set -euo pipefail
CHECK_NAME=check:syntax
# shellcheck source=tools/checks/lib.bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"
require yq "Run tools/bootstrap.sh to install the Toolchain."
require python3 "Run tools/bootstrap.sh to install the Toolchain."

yaml=()
other=()
while IFS= read -r -d '' f; do yaml+=("$f"); done < <(select_files yaml -- "$@")
while IFS= read -r -d '' f; do
  other+=("$(file_kind "$f"):$f")
done < <(select_files json jsonc toml -- "$@")

status=0
for f in ${yaml[@]+"${yaml[@]}"}; do
  if ! err="$(yq '.' "$f" 2>&1 >/dev/null)"; then
    echo "$f: invalid YAML: $err" >&2
    status=1
  fi
done
if ((${#other[@]})); then
  python3 -I "$DOTFILES_ROOT/tools/checks/syntax.py" "${other[@]}" || status=1
fi

((status == 0)) && echo "$CHECK_NAME: $((${#yaml[@]} + ${#other[@]})) file(s) ok"
exit "$status"
