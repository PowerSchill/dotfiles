#!/usr/bin/env bash
# Run gitleaks over every commit being pushed, so commits made with
# `git commit --no-verify` (or by chezmoi's autoCommit) are still checked.
set -euo pipefail

if [[ "${PRE_COMMIT_FROM_REF:-}" =~ ^0*$ ]]; then
    log_opts="$PRE_COMMIT_TO_REF --not --remotes"
else
    log_opts="$PRE_COMMIT_FROM_REF..$PRE_COMMIT_TO_REF"
fi

exec gitleaks git --no-banner --redact --verbose --log-opts="$log_opts" .
