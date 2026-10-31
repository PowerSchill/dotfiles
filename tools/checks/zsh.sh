#!/usr/bin/env bash
# Check: zsh files parse (`zsh -n`). shellcheck does not support zsh.
# zsh templates are rendered first with Ephemeral-machine data.
set -euo pipefail
CHECK_NAME=check:zsh
# shellcheck source=tools/checks/lib.bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

plain=()
templates=()
while IFS= read -r -d '' f; do plain+=("$f"); done < <(select_files zsh -- "$@")
while IFS= read -r -d '' f; do templates+=("$f"); done < <(select_files zsh-template -- "$@")
((${#plain[@]} + ${#templates[@]})) || exit 0

require zsh "It is a system prerequisite (not installable by mise): apt-get install zsh, dnf install zsh, or brew install zsh."

status=0
for f in ${plain[@]+"${plain[@]}"}; do
  zsh -n "$f" || status=1
done
for f in ${templates[@]+"${templates[@]}"}; do
  rendered="$DOTFILES_ROOT/.cache/render/zsh/$f"
  mkdir -p "$(dirname "$rendered")"
  if ! render_template "$f" >"$rendered"; then
    echo "$f: template failed to render" >&2
    status=1
    continue
  fi
  zsh -n "$rendered" 2>&1 | sed "s|$rendered|$f (rendered)|g"
  [[ "${PIPESTATUS[0]}" -eq 0 ]] || status=1
done

((status == 0)) && echo "$CHECK_NAME: $((${#plain[@]} + ${#templates[@]})) file(s) ok"
exit "$status"
