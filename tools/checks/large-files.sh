#!/usr/bin/env bash
# Check: no file over the size limit (default 1024 KB) enters the repo.
set -euo pipefail
CHECK_NAME=check:large-files
# shellcheck source=tools/checks/lib.bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

limit_kb="${DOTFILES_MAX_FILE_KB:-1024}"
status=0
count=0
while IFS= read -r -d '' f; do
  [[ -f "$f" ]] || continue
  count=$((count + 1))
  kb=$((($(wc -c <"$f") + 1023) / 1024))
  if ((kb > limit_kb)); then
    echo "$f: ${kb} KB exceeds the ${limit_kb} KB limit" >&2
    status=1
  fi
done < <(candidate_files "$@")

((status == 0)) && echo "$CHECK_NAME: $count file(s) ok"
exit "$status"
