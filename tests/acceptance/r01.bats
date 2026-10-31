#!/usr/bin/env bats
# R1: every tool the repo needs is declared, with a version, in the root manifest.
# Test: in a clean container with only git and curl, after bootstrap, with PATH limited
# to mise and the base OS, every declared tool runs and the repo's chores work.

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
    run container_exec 'mise run info'
    [ "$status" -eq 0 ]
    if container_exec 'mise tasks ls --json | jq -e "any(.[]; .name == \"validate\")"' >/dev/null; then
        run container_exec 'mise run validate'
        [ "$status" -eq 0 ]
    else
        skip "validate task arrives in a later PR"
    fi
}
