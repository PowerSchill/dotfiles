#!/usr/bin/env bats
# R11: commands accept parameters, for example "check one specific file".
# Test: a Check given one file checks only that file. (Running one test file is
# covered once the `test` task exists.)

load helpers

setup() { cd "$REPO_ROOT" || return 1; }

@test "R11: check:shellcheck with one file checks exactly one file" {
  run mise run -q check:shellcheck tools/bootstrap.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"check:shellcheck: 1 file(s) ok"* ]]
}

@test "R11: file arguments with spaces are passed through intact" {
  f="home/private_Library/private_Application Support/private_Cursor/User/settings.json"
  run mise run -q check:syntax "$f"
  [ "$status" -eq 0 ]
  [[ "$output" == *"check:syntax: 1 file(s) ok"* ]]
}

@test "R11: tasks document their parameters" {
  run mise run check:secrets --help
  [[ "$output" == *"--range"* ]]
}
