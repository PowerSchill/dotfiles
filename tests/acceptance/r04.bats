#!/usr/bin/env bats
# R4: the manifest works on Linux, macOS, WSL and containers, and fresh
# environments trust it non-interactively.
# Test: bootstrap and `mise run check` succeed with stdin closed in fresh
# Ubuntu, Debian and Fedora containers, without a trust prompt. macOS and WSL
# run the same commands in CI (validate on macos-latest; the weekly wsl job).

load helpers

teardown() { container_stop; }

bootstrap_and_check() {
  ACCEPTANCE_IMAGE="$1" container_start
  run container_exec 'tools/bootstrap.sh && mise run -q check'
  echo "$output"
  [ "$status" -eq 0 ]
  [[ "$output" != *"not trusted"* && "$output" != *"Trust"* ]]
}

@test "R4: Ubuntu container" { bootstrap_and_check ubuntu:24.04; }
@test "R4: Debian container" { bootstrap_and_check debian:13; }
@test "R4: Fedora container" { bootstrap_and_check fedora:43; }
