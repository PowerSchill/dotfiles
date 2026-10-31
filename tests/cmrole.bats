#!/usr/bin/env bats
# cmrole (home/dot_config/zsh/functions/role.zsh): change this Machine's Roles.
# chezmoi is replaced by a fake that records its arguments.

load helpers

setup() {
  command -v zsh >/dev/null || skip "zsh is not installed"
  export HOME="$BATS_TEST_TMPDIR/fakehome" XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/fakehome/.config"
  mkdir -p "$XDG_CONFIG_HOME/chezmoi" "$BATS_TEST_TMPDIR/bin"
  export CALLS="$BATS_TEST_TMPDIR/calls"
  # shellcheck disable=SC2016 # the fake script expands $* itself
  printf '#!/bin/sh\necho "chezmoi $*" >>"$CALLS"\n' >"$BATS_TEST_TMPDIR/bin/chezmoi"
  chmod +x "$BATS_TEST_TMPDIR/bin/chezmoi"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

cmrole() {
  zsh -fc "source '$SOURCE_DIR/dot_config/zsh/functions/role.zsh'; cmrole $*"
}

@test "add drives chezmoi init --promptBool, then apply" {
  run cmrole add security
  [ "$status" -eq 0 ]
  [ "$(cat "$CALLS")" = "chezmoi init --promptBool security=true
chezmoi apply" ]
}

@test "remove sets the Role to false" {
  run cmrole remove onepassword
  [ "$status" -eq 0 ]
  [[ "$(head -1 "$CALLS")" == "chezmoi init --promptBool onepassword=false" ]]
}

@test "an unknown Role is rejected without calling chezmoi" {
  run cmrole add gaming
  [ "$status" -eq 1 ]
  [[ "$output" == *"unknown role 'gaming'"* ]]
  [ ! -e "$CALLS" ]
}

@test "list shows enabled Roles from the chezmoi config" {
  printf 'data:\n  role:\n    dev: true\n    gui: false\n' >"$XDG_CONFIG_HOME/chezmoi/chezmoi.yaml"
  run cmrole list
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓"*"dev"* ]]
  [[ "$(grep gui <<<"$output")" != *"✓"* ]]
}
