#!/usr/bin/env bats
# R10: commands that write to the real home directory refuse to run without an
# explicit confirmation flag; previews and dry runs are the default.
# Test: `apply` without --yes exits non-zero and the home directory is unchanged.
# Runs on the host against a scratch HOME with a synthetic chezmoi config.

load helpers

setup() {
  cd "$REPO_ROOT" || return 1
  # Keep using the real Toolchain: without this, mise would reinstall every tool
  # into the fake home (its data dir follows HOME).
  export MISE_DATA_DIR="${MISE_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/mise}"
  export MISE_TRUSTED_CONFIG_PATHS="$REPO_ROOT${MISE_TRUSTED_CONFIG_PATHS:+:$MISE_TRUSTED_CONFIG_PATHS}"
  export HOME="$BATS_TEST_TMPDIR/fakehome" XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/fakehome/.config"
  unset XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME
  mkdir -p "$XDG_CONFIG_HOME/chezmoi"
  # Keep mise's own caches out of the home directory being measured.
  export MISE_CACHE_DIR="$BATS_TEST_TMPDIR/mise-cache" MISE_STATE_DIR="$BATS_TEST_TMPDIR/mise-state"
  tools/bin/dotfiles-role-config ephemeral "$BATS_TEST_TMPDIR/cfg" >/dev/null
  cp "$BATS_TEST_TMPDIR/cfg/chezmoi.yaml" "$XDG_CONFIG_HOME/chezmoi/chezmoi.yaml"
}

# One "hash  path" line per file, so a failure shows which files changed.
home_snapshot() {
  (cd "$HOME" && find . -type f -print0 | sort -z | xargs -0 -r shasum -a 256)
}

assert_home_unchanged() {
  local now
  now="$(home_snapshot)"
  [ "$now" = "$1" ] || {
    echo "files changed in HOME:"
    diff <(echo "$1") <(echo "$now") || true
    return 1
  }
}

@test "R10: apply without --yes exits non-zero and leaves HOME unchanged" {
  before="$(home_snapshot)"
  run mise run -q apply --no-externals
  [ "$status" -ne 0 ]
  [[ "$output" == *"refusing to write"* ]]
  assert_home_unchanged "$before"
}

@test "R10: preview is read-only" {
  before="$(home_snapshot)"
  run mise run -q preview --no-externals
  [ "$status" -eq 0 ]
  assert_home_unchanged "$before"
}

@test "R10: apply --yes runs chezmoi apply (observed with a fake chezmoi)" {
  fake="$BATS_TEST_TMPDIR/fake-chezmoi"
  # shellcheck disable=SC2016 # the fake expands $* itself
  printf '#!/bin/sh\necho "chezmoi $*" >>"%s/calls"\n' "$BATS_TEST_TMPDIR" >"$fake"
  chmod +x "$fake"
  DOTFILES_CHEZMOI="$fake" run mise run -q apply --yes
  [ "$status" -eq 0 ]
  [ "$(cat "$BATS_TEST_TMPDIR/calls")" = "chezmoi --source $REPO_ROOT apply" ]
}

@test "R10: the dry-run apply never writes to the scratch home" {
  run mise run -q check:apply
  [ "$status" -eq 0 ]
  [ -z "$(find .cache/apply/ephemeral/home -mindepth 1 -print -quit)" ]
}

@test "R10: preview accepts target files" {
  run mise run -q preview --no-externals "$HOME/.zshrc"
  [ "$status" -eq 0 ]
  [[ "$output" == *".zshrc"* ]]
  [[ "$output" != *".gitconfig"* ]]
}
