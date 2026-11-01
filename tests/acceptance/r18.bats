#!/usr/bin/env bats
# R18: a containerized dev environment can be built from the repo and reused by
# other projects.
# Test: build the image with `mise run devcontainer:build`; it runs as vscode
# with zsh and these dotfiles applied as an Ephemeral machine, carries the
# pinned Toolchain, and another project can install its own tools in it.

# Commands in single quotes are expanded inside the container, not here.
# shellcheck disable=SC2016

load helpers

IMAGE="dotfiles-dev:acceptance"

setup_file() {
  require_docker
  cd "$REPO_ROOT" || return 1
  mise run -q devcontainer:build --tag "$IMAGE" >&3 2>&1
}

in_image() {
  docker run --rm "$@"
}

@test "R18: the image runs as vscode with zsh as the login shell" {
  run in_image "$IMAGE" sh -c 'whoami; getent passwd "$(whoami)" | cut -d: -f7'
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = vscode ]
  [ "${lines[1]}" = /usr/bin/zsh ]
}

@test "R18: the dotfiles are applied as an Ephemeral machine" {
  run in_image "$IMAGE" sh -c 'test -f ~/.zshrc && test -d ~/.oh-my-zsh && chezmoi data --format json'
  [ "$status" -eq 0 ]
  [ "$(jq -r .ephemeral <<<"$output")" = true ]
  [ "$(jq -c .roles <<<"$output")" = '["dev"]' ]
}

@test "R18: an interactive zsh starts without errors" {
  run in_image "$IMAGE" zsh -lic 'echo READY' 2>&1
  [ "$status" -eq 0 ]
  [[ "$output" == *READY* ]]
  [[ "$output" != *"command not found"* && "$output" != *"no such file"* ]]
}

@test "R18: the image carries the pinned Toolchain" {
  run in_image -w /home/vscode/.local/share/chezmoi "$IMAGE" mise x -- chezmoi --version
  [ "$status" -eq 0 ]
  [[ "$output" == *"v$(pinned_version chezmoi)"* ]]
}

@test "R18: another project can use the image with its own mise.toml" {
  project="$BATS_TEST_TMPDIR/other-project"
  mkdir -p "$project"
  printf '[tools]\njq = "1.8.2"\n' >"$project/mise.toml"
  run in_image -v "$project:/workspaces/other-project" -w /workspaces/other-project \
    -e MISE_TRUSTED_CONFIG_PATHS=/workspaces/other-project -e MISE_YES=1 \
    "$IMAGE" sh -c 'mise install -q && mise x -- jq --version'
  echo "$output"
  [ "$status" -eq 0 ]
  [[ "$output" == *"jq-1.8.2"* ]]
}
