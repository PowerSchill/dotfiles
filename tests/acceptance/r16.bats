#!/usr/bin/env bats
# R16: the minimal Profile installs the provisioning tool but not the optional extras.
# Test: in minimal, chezmoi runs and none of the mise.full.toml tools are installed.

load helpers

setup_file() {
  container_start
  container_exec 'DOTFILES_PROFILE=minimal tools/bootstrap.sh' >&3
}

teardown_file() { container_stop; }

@test "R16: chezmoi (the provisioning tool) is installed" {
  run container_exec 'mise x -- chezmoi --version'
  [ "$status" -eq 0 ]
  [[ "$output" == *"v$(pinned_version chezmoi)"* ]]
}

@test "R16: no optional extra from mise.full.toml is installed" {
  for bin in git-cliff act devcontainer; do
    run container_exec "mise which $bin"
    [ "$status" -ne 0 ] || {
      echo "$bin should not be installed in minimal"
      return 1
    }
  done
}
