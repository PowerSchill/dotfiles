#!/usr/bin/env bats
# R5: declared tools run at their pinned version without being globally installed.
# Test: shellcheck is not on the base PATH, but `mise x -- shellcheck` runs the pinned version.

load helpers

setup_file() {
    container_start
    container_exec tools/bootstrap.sh >&3
}

teardown_file() { container_stop; }

@test "R5: shellcheck is not globally installed" {
    run container_exec 'PATH=/usr/local/bin:/usr/bin:/bin command -v shellcheck'
    [ "$status" -ne 0 ]
}

@test "R5: mise x runs the pinned shellcheck" {
    run container_exec 'PATH=$HOME/.local/bin:/usr/bin:/bin mise x -- shellcheck --version'
    [ "$status" -eq 0 ]
    [[ "$output" == *"version: $(pinned_version shellcheck)"* ]]
}
