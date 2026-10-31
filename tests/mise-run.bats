#!/usr/bin/env bats
# tools/hooks/mise-run: how git hooks find mise.

load helpers

setup() {
  export HOME="$BATS_TEST_TMPDIR/fakehome"
  mkdir -p "$HOME/.local/bin"
}

@test "fails with bootstrap instructions when mise is missing" {
  run env -i HOME="$HOME" PATH=/usr/bin:/bin bash "$REPO_ROOT/tools/hooks/mise-run" check
  [ "$status" -eq 1 ]
  [[ "$output" == *"Run tools/bootstrap.sh"* ]]
}

@test "finds mise in ~/.local/bin when it is not on PATH" {
  printf '#!/bin/sh\necho "fake mise $*"\n' >"$HOME/.local/bin/mise"
  chmod +x "$HOME/.local/bin/mise"
  run env -i HOME="$HOME" PATH=/usr/bin:/bin bash "$REPO_ROOT/tools/hooks/mise-run" check:shfmt a.sh
  [ "$status" -eq 0 ]
  [ "$output" = "fake mise run --quiet check:shfmt a.sh" ]
}
