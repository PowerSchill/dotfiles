#!/usr/bin/env bats
# R12: one command runs every Check that must pass before commit.
# Test: `check` depends on exactly the Checks the commit hook runs, and passes on the repo.

load helpers

setup() { cd "$REPO_ROOT" || return 1; }

@test "R12: check's dependencies equal the commit hook's Checks" {
  deps="$(mise tasks deps check --dot 2>/dev/null | grep -o '"check:[a-z-]*"' | tr -d '"' | sort -u)" || true
  if [ -z "$deps" ]; then
    deps="$(mise tasks info check --json | jq -r '.depends[]' | sort -u)"
  fi
  hooks="$(yq -r '.repos[].hooks[] | select((.stages // ["pre-commit"]) | contains(["pre-commit"])) | "check:" + .id' \
    .pre-commit-config.yaml | sort -u)"
  echo "check depends on:"
  echo "$deps"
  echo "commit hook runs:"
  echo "$hooks"
  [ "$deps" = "$hooks" ]
}

@test "R12: every hook calls the task named after it" {
  run yq -r '.repos[].hooks[] | select(.entry != "tools/hooks/mise-run check:" + .id) | .id' .pre-commit-config.yaml
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "R12: no hook pins its own tool version (versions live in mise.toml)" {
  run yq -r '.repos[] | select(.repo != "local") | .repo' .pre-commit-config.yaml
  [ -z "$output" ]
  run yq -r '.repos[].hooks[] | select(.additional_dependencies) | .id' .pre-commit-config.yaml
  [ -z "$output" ]
}

@test "R12: mise run check passes on the repo" {
  run mise run -q check
  echo "$output"
  [ "$status" -eq 0 ]
}
