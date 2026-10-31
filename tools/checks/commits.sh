#!/usr/bin/env bash
# Check: commit messages follow Conventional Commits with this repo's types.
#
#   commits.sh                       commits since the last pre-Conventional commit
#   commits.sh A..B                  commits in a range
#   commits.sh --message-file FILE   one message (the commit-msg hook)
#
# cocogitto validates the Conventional Commits structure; the type list below
# is this repo's own (cocogitto also accepts build, style, ...).
set -euo pipefail
CHECK_NAME=check:commits
# shellcheck source=tools/checks/lib.bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"
require cog "Run tools/bootstrap.sh to install the Toolchain."

TYPES='feat|fix|perf|refactor|docs|test|ci|chore|revert'
SUBJECT_RE="^($TYPES)(\\([a-z0-9._/-]+\\))?!?: [^ ]"

# Prints a problem and returns 1 if the message is not acceptable.
check_message() {
  local label="$1" msg="$2" subject err
  subject="${msg%%$'\n'*}"
  # Outside the repo: cog otherwise opens it and panics when git has no user.name.
  if ! err="$(cd / && cog verify "$msg" 2>&1)"; then
    printf '%s: not a Conventional Commit: %s\n%s\n' "$label" "$subject" "$err" >&2
    return 1
  fi
  if [[ ! "$subject" =~ $SUBJECT_RE ]]; then
    printf '%s: type must be one of %s, with an optional lowercase scope: %s\n' \
      "$label" "${TYPES//|/, }" "$subject" >&2
    return 1
  fi
}

if [[ "${1:-}" == --message-file ]]; then
  file="${2:?--message-file needs a path}"
  # Drop git's comment lines, as git itself does when it records the message.
  msg="$(grep -v '^#' "$file" || true)"
  subject="${msg%%$'\n'*}"
  # Let `git commit --fixup` through; autosquash removes these before they land.
  [[ "$subject" == fixup!* || "$subject" == squash!* || "$subject" == amend!* ]] && exit 0
  check_message "commit message" "$msg"
  exit
fi

range="${1:-${DOTFILES_CONVENTIONAL_SINCE:?DOTFILES_CONVENTIONAL_SINCE is not set (see mise.toml)}..HEAD}"
status=0
count=0
while IFS= read -r sha; do
  count=$((count + 1))
  check_message "${sha:0:9}" "$(git log -1 --format=%B "$sha")" || status=1
done < <(git rev-list --no-merges "$range")

((status == 0)) && echo "$CHECK_NAME: $count commit(s) ok in $range"
exit "$status"
