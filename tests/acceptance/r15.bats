#!/usr/bin/env bats
# R15: at least two Profiles, chosen automatically from the environment, overridable.
# Test: a CI environment selects minimal and the extras are absent; the override wins;
# a plain workstation environment selects full.

load helpers

teardown() { container_stop; }

@test "R15: CI selects minimal" {
    run host_profile CI=true
    [ "$output" = "minimal" ]
}

@test "R15: Codespaces and dev containers select minimal" {
    run host_profile CODESPACES=true
    [ "$output" = "minimal" ]
    run host_profile REMOTE_CONTAINERS_IPC=/tmp/x
    [ "$output" = "minimal" ]
}

@test "R15: a container marker file selects minimal" {
    marker="$BATS_TEST_TMPDIR/dockerenv"
    touch "$marker"
    DOTFILES_CONTAINER_MARKERS="$marker" run host_profile
    [ "$output" = "minimal" ]
}

@test "R15: a plain environment selects full" {
    run host_profile
    [ "$output" = "full" ]
}

@test "R15: DOTFILES_PROFILE overrides detection" {
    run host_profile CI=true DOTFILES_PROFILE=full
    [ "$output" = "full" ]
    run host_profile DOTFILES_PROFILE=minimal
    [ "$output" = "minimal" ]
}

@test "R15: an unknown DOTFILES_PROFILE is rejected" {
    run host_profile DOTFILES_PROFILE=everything
    [ "$status" -eq 2 ]
}

@test "R15: in simulated CI the minimal Toolchain is installed and extras are absent" {
    container_start -e CI=true
    run container_exec 'CI=true tools/bootstrap.sh'
    [ "$status" -eq 0 ]
    run container_exec 'CI=true mise which git-cliff'
    [ "$status" -ne 0 ]
}

@test "R15: DOTFILES_PROFILE=full in CI installs the extras" {
    container_start -e CI=true
    run container_exec 'CI=true DOTFILES_PROFILE=full tools/bootstrap.sh'
    [ "$status" -eq 0 ]
    run container_exec 'mise which git-cliff'
    [ "$status" -eq 0 ]
}
