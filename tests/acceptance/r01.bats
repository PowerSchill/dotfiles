#!/usr/bin/env bats
# R1: every tool the repo needs is declared, with a version, in the root manifest.
# Test: in a clean container with only git, curl and zsh (a declared system
# prerequisite), after bootstrap, with PATH limited to mise and the base OS, every
# declared tool runs and `mise run validate` passes.

# Commands in single quotes are expanded inside the container, not here.
# shellcheck disable=SC2016

load helpers

setup_file() {
  container_start
  container_exec tools/bootstrap.sh >&3
}

teardown_file() { container_stop; }

@test "R1: every tool in mise.toml is installed and runnable" {
  run container_exec 'mise ls --current --json | jq -e "[.[][] | select(.installed | not)] | length == 0"'
  [ "$status" -eq 0 ]
}

@test "R1: every tool in mise.toml has an exact version or 'latest'" {
  run container_exec 'mise ls --current --json |
        jq -r "to_entries[] | .key as \$t | .value[] | \"\(\$t) \(.requested_version)\"" |
        grep -Ev " ([0-9]+\.[0-9]+\.[0-9]+|latest)$"'
  [ "$status" -eq 1 ] # grep found no loose versions
}

@test "R1: the repo's chores run using only declared tools" {
  run container_exec 'mise run info && mise run validate'
  echo "$output"
  [ "$status" -eq 0 ]
}
