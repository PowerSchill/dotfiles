#!/usr/bin/env bats
# tools/hooks/check-private-info.sh: blocks private information from this public repo.
# Lines with emails or home paths carry `allow-private-info` so this file can be committed.

load helpers

setup() {
  scratch_git
  # Never read the developer's real denylist.
  export DOTFILES_PRIVATE_PATTERNS="$BATS_TEST_TMPDIR/patterns"
  : >"$DOTFILES_PRIVATE_PATTERNS"
}

check() { "$REPO_ROOT/tools/hooks/check-private-info.sh"; }

stage() {
  printf '%s\n' "$2" >"$1"
  git add "$1"
}

@test "passes when nothing private is staged" {
  stage notes.txt "hello world"
  run check
  [ "$status" -eq 0 ]
}

@test "rejects an email outside the allowed domains" {
  stage notes.txt "contact someone@corp-example.io" # allow-private-info
  run check
  [ "$status" -eq 1 ]
  [[ "$output" == *"email address"* ]]
}

@test "allows emails in allowed domains and git@ remotes" {
  stage notes.txt "a@example.com git@github.com:x/y.git"
  run check
  [ "$status" -eq 0 ]
}

@test "rejects another user's home path, allows the owner's" {
  stage a.txt "/Users/alice/projects" # allow-private-info
  run check
  [ "$status" -eq 1 ]
  [[ "$output" == *"home path for user 'alice'"* ]]
  git reset -q
  stage b.txt "/home/runner/work"
  rm a.txt
  run check
  [ "$status" -eq 0 ]
}

@test "rejects key and credential files by name" {
  stage private_id_ed25519 "not really a key"
  run check
  [ "$status" -eq 1 ]
  [[ "$output" == *"forbidden file"* ]]
}

@test "encrypted_ files are exempt from the filename rule" {
  stage encrypted_private_id_ed25519.age "ciphertext"
  run check
  [ "$status" -eq 0 ]
}

@test "rejects lines matching the local denylist" {
  echo 'megacorp' >"$DOTFILES_PRIVATE_PATTERNS"
  stage notes.txt "ssh build.MegaCorp.internal"
  run check
  [ "$status" -eq 1 ]
  [[ "$output" == *"matches private pattern"* ]]
}

@test "allow-private-info exempts a single line" {
  echo 'megacorp' >"$DOTFILES_PRIVATE_PATTERNS"
  stage notes.txt "megacorp # allow-private-info"
  run check
  [ "$status" -eq 0 ]
}

@test "range mode scans committed lines (pre-push and CI)" {
  stage notes.txt "contact someone@corp-example.io" # allow-private-info
  git commit -q -m "test: leak"
  run env PRE_COMMIT_FROM_REF=HEAD~1 PRE_COMMIT_TO_REF=HEAD "$REPO_ROOT/tools/hooks/check-private-info.sh"
  [ "$status" -eq 1 ]
  run "$REPO_ROOT/tools/checks/private-info.sh" --range HEAD~1..HEAD
  [ "$status" -eq 1 ]
}
