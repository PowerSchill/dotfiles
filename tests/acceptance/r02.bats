#!/usr/bin/env bats
# R2: one command installs exactly the pinned versions, with no prompts, and is idempotent.
# Test: on a clean container run the install command twice; both exit 0 and the second
# changes nothing.

load helpers

setup_file() { container_start; }
teardown_file() { container_stop; }

snapshot() {
  container_exec 'find ~/.local/bin ~/.local/share/mise/installs -type f -print0 2>/dev/null |
        sort -z | xargs -0 sha256sum | sha256sum; git status --porcelain'
}

@test "R2: first bootstrap exits 0 without prompting" {
  run container_exec tools/bootstrap.sh
  echo "$output"
  [ "$status" -eq 0 ]
}

@test "R2: installed versions match the pins exactly" {
  run container_exec 'mise x -- shellcheck --version'
  [[ "$output" == *"version: $(pinned_version shellcheck)"* ]]
  run container_exec 'mise x -- chezmoi --version'
  [[ "$output" == *"v$(pinned_version chezmoi)"* ]]
}

@test "R2: second bootstrap exits 0 and changes nothing" {
  before="$(snapshot)"
  run container_exec tools/bootstrap.sh
  echo "$output"
  [ "$status" -eq 0 ]
  [ "$(snapshot)" = "$before" ]
}
