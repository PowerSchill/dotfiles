#!/usr/bin/env bash
# Check: lint shell scripts with shellcheck.
# *.sh.tmpl scripts are rendered first, once as an Ephemeral machine and once
# with every Role (lib.bash RENDER_VARIANTS); findings point at the rendered
# file, so line numbers can differ from the template.
set -euo pipefail
CHECK_NAME=check:shellcheck
# shellcheck source=tools/checks/lib.bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"
require shellcheck "Run tools/bootstrap.sh to install the Toolchain."

plain=()
templates=()
while IFS= read -r -d '' f; do plain+=("$f"); done < <(select_files shell -- "$@")
while IFS= read -r -d '' f; do templates+=("$f"); done < <(select_files shell-template -- "$@")

status=0
if ((${#plain[@]})); then
  shellcheck "${plain[@]}" || status=1
fi

for f in ${templates[@]+"${templates[@]}"}; do
  for variant in "${RENDER_VARIANTS[@]}"; do
    rendered="$DOTFILES_ROOT/.cache/render/$variant/scripts/$f"
    mkdir -p "$(dirname "$rendered")"
    if ! render_template "$variant" "$f" >"$rendered"; then
      echo "$f: template failed to render (roles: $variant)" >&2
      status=1
      continue
    fi
    # A template that renders to nothing is disabled for this OS or Role set.
    grep -q '[^[:space:]]' "$rendered" || continue
    if ! shellcheck "$rendered" 2>&1 | sed "s|$rendered|$f (rendered, roles: $variant)|g"; then
      status=1
    fi
  done
done

total=$((${#plain[@]} + ${#templates[@]}))
((status == 0)) && echo "$CHECK_NAME: $total file(s) ok"
exit "$status"
