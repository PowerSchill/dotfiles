# shellcheck shell=bash
# Shared helpers for the bats unit tests in tests/ (acceptance tests live in
# tests/acceptance/). Unit tests run on the host and never touch $HOME.

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
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
# (comma-separated) on a non-Ephemeral machine, and print its path.
#   cfg="$(role_config dev,onepassword)"
role_config() {
  local roles="$1" dir="$BATS_TEST_TMPDIR/chezmoi-$1" r
  mkdir -p "$dir"
  CODESPACES=true chezmoi --source "$REPO_ROOT" --config "$dir/none.yaml" \
    --persistent-state "$dir/state.boltdb" --no-tty \
    execute-template --init <"$SOURCE_DIR/.chezmoi.yaml.tmpl" >"$dir/base.yaml"
  cp "$dir/base.yaml" "$dir/chezmoi.yaml"
  yq -i '.data.ephemeral = false | .data.roles = []' "$dir/chezmoi.yaml"
  for r in $(yq '.data.role | keys | .[]' "$dir/base.yaml"); do
    if [[ ",$roles," == *",$r,"* ]]; then
      NAME="$r" yq -i '.data.role[env(NAME)] = true | .data.roles += [env(NAME)]' "$dir/chezmoi.yaml"
    else
      NAME="$r" yq -i '.data.role[env(NAME)] = false' "$dir/chezmoi.yaml"
    fi
  done
  echo "$dir/chezmoi.yaml"
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
