#!/usr/bin/env bats
# tools/checks/commits.sh: Conventional Commits with this repo's types, and the
# message chezmoi's autoCommit writes (home/.commit_message.tmpl).

load helpers

setup() {
  scratch_git
  export DOTFILES_CONVENTIONAL_SINCE
  DOTFILES_CONVENTIONAL_SINCE="$(git rev-parse HEAD)"
}

commit() { git commit -q --allow-empty -m "$1"; }
msg_file() {
  printf '%b' "$1" >"$BATS_TEST_TMPDIR/MSG"
  "$REPO_ROOT/tools/checks/commits.sh" --message-file "$BATS_TEST_TMPDIR/MSG"
}

@test "accepts the agreed types, with and without a scope" {
  commit "feat(zsh): add an alias"
  commit "fix: repair a script"
  commit "chore(chezmoi): update .zshrc"
  commit "revert!: undo a breaking change"
  run "$REPO_ROOT/tools/checks/commits.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"4 commit(s) ok"* ]]
}

@test "rejects types outside the list, even if cocogitto accepts them" {
  commit "build: bump something"
  run "$REPO_ROOT/tools/checks/commits.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"type must be one of"* ]]
}

@test "rejects messages that are not Conventional Commits" {
  commit "Add a thing"
  run "$REPO_ROOT/tools/checks/commits.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not a Conventional Commit"* ]]
}

@test "rejects an uppercase scope" {
  commit "feat(ZSH): add an alias"
  run "$REPO_ROOT/tools/checks/commits.sh"
  [ "$status" -eq 1 ]
}

@test "commits before DOTFILES_CONVENTIONAL_SINCE are not checked" {
  commit "Old style message"
  DOTFILES_CONVENTIONAL_SINCE="$(git rev-parse HEAD)"
  commit "feat: new style"
  run "$REPO_ROOT/tools/checks/commits.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"1 commit(s) ok"* ]]
}

@test "the commit-msg mode ignores git comments and lets fixups through" {
  run msg_file 'docs: explain roles\n# Please enter the commit message\n'
  [ "$status" -eq 0 ]
  run msg_file 'fixup! docs: explain roles\n'
  [ "$status" -eq 0 ]
  run msg_file 'Explain roles\n'
  [ "$status" -eq 1 ]
}

@test "chezmoi autoCommit messages pass the commit-msg check" {
  src="$BATS_TEST_TMPDIR/git" dest="$BATS_TEST_TMPDIR/dest"
  cp "$SOURCE_DIR/.commit_message.tmpl" "$src/"
  git add .commit_message.tmpl && git commit -q -m "test: template"
  cfg="$BATS_TEST_TMPDIR/chezmoi-config"
  mkdir -p "$dest" "$cfg"
  printf 'git:\n  autoCommit: true\n  commitMessageTemplateFile: .commit_message.tmpl\n' >"$cfg/c.yaml"
  chez() {
    chezmoi --source "$src" --destination "$dest" --config "$cfg/c.yaml" \
      --persistent-state "$cfg/s.db" --no-tty "$@"
  }

  echo one >"$dest/.one"
  chez add "$dest/.one"
  [ "$(git log -1 --format=%s)" = "chore(chezmoi): add .one" ]
  git log -1 --format=%B >"$BATS_TEST_TMPDIR/MSG"
  run "$REPO_ROOT/tools/checks/commits.sh" --message-file "$BATS_TEST_TMPDIR/MSG"
  [ "$status" -eq 0 ]

  echo two >"$dest/.two"
  echo three >"$dest/.three"
  chez add "$dest/.two" "$dest/.three"
  [ "$(git log -1 --format=%s)" = "chore(chezmoi): update 2 files" ]
  [[ "$(git log -1 --format=%b)" == *"- add .three"* ]]
}
