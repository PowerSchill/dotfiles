#!/usr/bin/env bats
# R6: repo-level environment defaults are declared alongside the tools.
# Test: `mise env` contains the declared PATH entry and variables, and tasks see them.

load helpers

setup_file() {
  container_start
  container_exec tools/bootstrap.sh >&3
}

teardown_file() { container_stop; }

@test "R6: tools/bin is added to PATH" {
  run container_exec 'mise env --json | jq -r .PATH'
  [[ "$output" == *"$CONTAINER_REPO/tools/bin"* ]]
}

@test "R6: declared variables are exported to tools" {
  run container_exec 'mise x -- printenv DOTFILES_ROOT'
  [ "$output" = "$CONTAINER_REPO" ]
  run container_exec 'mise x -- printenv PYTHONDONTWRITEBYTECODE'
  [ "$output" = "1" ]
}
