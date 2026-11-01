#!/usr/bin/env bats
# tools/hooks/mise-run: how git hooks find mise.

load helpers

setup() {
  export HOME="$BATS_TEST_TMPDIR/fakehome"
  mkdir -p "$HOME/.local/bin"
}

@test "fails with bootstrap instructions when mise is missing" {
  # Rule out real installs (e.g. Homebrew's) so this Machine's mise is never run.
  run env -i HOME="$HOME" PATH=/usr/bin:/bin DOTFILES_MISE_LOCATIONS="$HOME/.local/bin/mise" \
    bash "$REPO_ROOT/tools/hooks/mise-run" check
  [ "$status" -eq 1 ]
  [[ "$output" == *"Run tools/bootstrap.sh"* ]]
}

@test "finds mise in ~/.local/bin when it is not on PATH" {
  printf '#!/bin/sh\necho "fake mise $*"\n' >"$HOME/.local/bin/mise"
  chmod +x "$HOME/.local/bin/mise"
  run env -i HOME="$HOME" PATH=/usr/bin:/bin DOTFILES_MISE_LOCATIONS="$HOME/.local/bin/mise" \
    bash "$REPO_ROOT/tools/hooks/mise-run" check:shfmt a.sh
  [ "$status" -eq 0 ]
  [ "$output" = "fake mise run --quiet check:shfmt a.sh" ]
}

@test "--exec runs a Toolchain command through mise exec" {
  printf '#!/bin/sh\necho "fake mise $*"\n' >"$HOME/.local/bin/mise"
  chmod +x "$HOME/.local/bin/mise"
  run env -i HOME="$HOME" PATH=/usr/bin:/bin DOTFILES_MISE_LOCATIONS="$HOME/.local/bin/mise" \
    bash "$REPO_ROOT/tools/hooks/mise-run" --exec pre-commit hook-impl
  [ "$status" -eq 0 ]
  [ "$output" = "fake mise exec -- pre-commit hook-impl" ]
}
