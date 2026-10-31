#!/usr/bin/env bash
# Check: no secrets, using gitleaks.
#   (no args)          staged changes (what is about to be committed)
#   --range A..B       commits in a range (CI, or a manual scan)
#   --all              the whole history
# At pre-push, pre-commit's PRE_COMMIT_FROM_REF/TO_REF select the pushed range,
# so commits made with --no-verify or by chezmoi's autoCommit are still checked.
set -euo pipefail
CHECK_NAME=check:secrets
# shellcheck source=tools/checks/lib.bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"
require gitleaks "Run tools/bootstrap.sh to install the Toolchain."

common=(--no-banner --redact --verbose)
range="${1:-}"
[[ "$range" == --range ]] && range="${2:?--range needs A..B}"

if [[ "$range" == --all ]]; then
  exec gitleaks git "${common[@]}" .
elif [[ -n "$range" ]]; then
  exec gitleaks git "${common[@]}" --log-opts="$range" .
elif [[ -n "${PRE_COMMIT_TO_REF:-}" ]]; then
  if [[ "${PRE_COMMIT_FROM_REF:-}" =~ ^0*$ ]]; then
    exec gitleaks git "${common[@]}" --log-opts="$PRE_COMMIT_TO_REF --not --remotes" .
  fi
  # At a push, skip commits a remote already has (merging main must not rescan it).
  exec gitleaks git "${common[@]}" \
    --log-opts="$PRE_COMMIT_FROM_REF..$PRE_COMMIT_TO_REF${PRE_COMMIT_REMOTE_NAME:+ --not --remotes}" .
else
  exec gitleaks git "${common[@]}" --pre-commit --staged .
fi
