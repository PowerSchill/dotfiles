#!/usr/bin/env bats
# R19: the repo can preview release notes from commit history locally, without
# publishing anything.
# Test: with the network disconnected, `release:preview` prints notes, and the
# working tree, tags and remotes are unchanged.

load helpers

# Commands in single quotes are expanded inside the container, not here.
# shellcheck disable=SC2016

setup_file() {
  container_start
  container_root 'DEBIAN_FRONTEND=noninteractive apt-get install -y -qq libatomic1 >/dev/null'
  container_exec 'DOTFILES_PROFILE=full tools/bootstrap.sh' >&3
  container_exec 'g() { git -c user.name=test -c user.email=acceptance-test "$@"; }
    g commit -q --no-verify --allow-empty -m "feat(zsh): a feature for the notes" &&
    g commit -q --no-verify --allow-empty -m "chore(chezmoi): update .zshrc"'
  docker network disconnect bridge "$CONTAINER"
}

teardown_file() { container_stop; }

state() {
  container_exec 'git status --porcelain; git tag; git remote -v; git rev-parse HEAD'
}

@test "R19: release:preview prints notes offline" {
  before="$(state)"
  run container_exec 'mise run -q release:preview --tag v2026.10.31'
  echo "$output"
  [ "$status" -eq 0 ]
  [[ "$output" == *"## v2026.10.31"* ]]
  [[ "$output" == *"a feature for the notes"* ]]
  [[ "$output" != *"update .zshrc"* ]] # chore commits are left out
  [ "$(state)" = "$before" ]
}

@test "R19: the network really is disconnected" {
  run container_exec 'curl -fsS --max-time 5 https://github.com >/dev/null'
  [ "$status" -ne 0 ]
}
