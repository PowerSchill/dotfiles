#!/usr/bin/env bash
# Check: no private information (see tools/hooks/check-private-info.sh).
#   (no args)          staged changes
#   --range A..B       added lines in a commit range (CI, or a manual scan)
set -euo pipefail
CHECK_NAME=check:private-info
# shellcheck source=tools/checks/lib.bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

if [[ "${1:-}" == --range ]]; then
  range="${2:?--range needs A..B}"
  [[ "$range" == *..* ]] || die "--range must look like A..B, got '$range'"
  export PRE_COMMIT_FROM_REF="${range%%..*}" PRE_COMMIT_TO_REF="${range##*..}"
fi
exec "$DOTFILES_ROOT/tools/hooks/check-private-info.sh"
