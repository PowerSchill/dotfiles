#!/usr/bin/env bats
# tools/release-tag.sh: guardrails around creating a Release tag (ADR 0003).

load helpers

setup() {
  scratch_git
  git init -q --bare "$BATS_TEST_TMPDIR/origin.git"
  git remote add origin "$BATS_TEST_TMPDIR/origin.git"
  git push -q origin main
  git fetch -q origin
}

tag() { "$REPO_ROOT/tools/release-tag.sh" "$@"; }

@test "refuses without --yes and creates nothing" {
  run tag --tag v2026.10.31
  [ "$status" -eq 1 ]
  [[ "$output" == *"without --yes"* ]]
  [ -z "$(git tag)" ]
}

@test "--yes creates an annotated tag and pushes it" {
  run tag --tag v2026.10.31 --yes
  [ "$status" -eq 0 ]
  [ "$(git cat-file -t v2026.10.31)" = tag ]
  git --git-dir="$BATS_TEST_TMPDIR/origin.git" rev-parse -q --verify refs/tags/v2026.10.31
}

@test "refuses a tag that already exists" {
  git tag v2026.10.31
  run tag --tag v2026.10.31 --yes
  [ "$status" -eq 1 ]
  [[ "$output" == *"already exists"* ]]
}

@test "refuses off main" {
  git checkout -q -b topic
  run tag --tag v2026.10.31 --yes
  [ "$status" -eq 1 ]
  [[ "$output" == *"not on main"* ]]
}

@test "refuses a dirty tree" {
  touch untracked
  run tag --tag v2026.10.31 --yes
  [ "$status" -eq 1 ]
  [[ "$output" == *"not clean"* ]]
}

@test "refuses when main is ahead of origin" {
  git commit -q --allow-empty -m "test: unpushed"
  run tag --tag v2026.10.31 --yes
  [ "$status" -eq 1 ]
  [[ "$output" == *"differs from origin/main"* ]]
  [ -z "$(git tag)" ]
}

@test "rejects a malformed tag name" {
  run tag --tag 1.0.0 --yes
  [ "$status" -eq 1 ]
  [[ "$output" == *"tag must look like"* ]]
}
