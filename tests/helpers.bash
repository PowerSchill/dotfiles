# shellcheck shell=bash
# Shared helpers for the bats unit tests in tests/ (acceptance tests live in
# tests/acceptance/). Unit tests run on the host and never touch $HOME.

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
# Ignore the developer's global and system git config: commit signing (for
# example through 1Password), hooks paths and identities must not leak in.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=acceptance-test
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=acceptance-test
SOURCE_DIR="$REPO_ROOT/$(cat "$REPO_ROOT/.chezmoiroot")"

# A throwaway git repo in the test's temp dir; cd into it.
scratch_git() {
  SCRATCH="$BATS_TEST_TMPDIR/git"
  mkdir -p "$SCRATCH"
  cd "$SCRATCH" || return 1
  git init -q -b main
  git config user.name test
  git config user.email acceptance-test
  git commit -q --allow-empty -m "test: root"
}

# Write a chezmoi config whose data enables exactly the given Roles
# (comma-separated, or `ephemeral`) and print its path.
#   cfg="$(role_config dev,onepassword)"
role_config() {
  "$REPO_ROOT/tools/bin/dotfiles-role-config" "$1" "$BATS_TEST_TMPDIR/chezmoi-$1"
}

# Render a source template with the given Roles enabled.
#   render_with dev,onepassword private_dot_gitconfig.tmpl
render_with() {
  local cfg
  cfg="$(role_config "$1")"
  chezmoi --source "$REPO_ROOT" --config "$cfg" \
    --persistent-state "$(dirname "$cfg")/state.boltdb" \
    --destination "$BATS_TEST_TMPDIR/fakehome" --no-tty \
    execute-template <"$SOURCE_DIR/$2"
}
