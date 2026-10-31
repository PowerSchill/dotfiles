#!/usr/bin/env bats
# R13: the same Checks run on commit and in CI, from the same definitions.
# Test: a deliberately broken shell script is rejected by `git commit` and by the
# command CI runs. (CI runs `mise run validate` once it exists; until then `check`.)

# Fixture scripts are written literally; their $1 must not expand here.
# shellcheck disable=SC2016

load helpers

setup() {
  scratch_repo
  # hooks:install skips itself in CI; this test needs the hooks installed.
  env -u CI mise run -q hooks:install >/dev/null
  printf '#!/usr/bin/env bash\nif [ -n $1 ]; then echo "$1"; fi\n' >broken.sh # SC2070
  git add broken.sh
}

ci_entry_point() {
  if mise tasks ls --json | jq -e 'any(.[]; .name == "validate")' >/dev/null; then
    mise run -q validate
  else
    mise run -q check
  fi
}

@test "R13: the commit hook rejects the broken script" {
  run commit_in_scratch -m "test: broken"
  echo "$output"
  [ "$status" -ne 0 ]
  [[ "$output" == *"SC2070"* ]]
}

@test "R13: the CI entry point rejects the broken script" {
  run ci_entry_point
  echo "$output"
  [ "$status" -ne 0 ]
  [[ "$output" == *"SC2070"* ]]
}

@test "R13: both accept the script once it is fixed" {
  printf '#!/usr/bin/env bash\nif [ -n "$1" ]; then echo "$1"; fi\n' >broken.sh
  git add broken.sh
  run commit_in_scratch -m "test: fixed"
  echo "$output"
  [ "$status" -eq 0 ]
  run ci_entry_point
  [ "$status" -eq 0 ]
}
