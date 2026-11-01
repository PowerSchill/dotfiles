#!/usr/bin/env bats
# R17: CI calls the same named commands a developer would, with no CI-only
# logic beyond reporting.
# Test: every workflow step is a `mise run <task>`, the bootstrap, an allowed
# action, or one of the listed plumbing steps.

load helpers

setup() { cd "$REPO_ROOT" || return 1; }

ALLOWED_ACTIONS='^(actions/checkout|actions/cache|actions/upload-artifact|Vampire/setup-wsl|docker/setup-qemu-action|docker/setup-buildx-action|docker/login-action)@[0-9a-f]{40}$'
ALLOWED_RUN='^((~/.local/bin/)?mise run [a-z][a-z:-]*( .*)?|tools/bootstrap\.sh)$'
# Environment plumbing, each commented "Plumbing" in the workflow (literal text).
# shellcheck disable=SC2016
PLUMBING=(
  'echo "$HOME/.local/bin" >> "$GITHUB_PATH"'
  'sudo apt-get update -qq && sudo apt-get install -y -qq zsh'
)

steps() {
  yq -o json -I0 '.jobs[].steps[]' .github/workflows/*.yml
}

@test "R17: every action is allowed and pinned to a commit" {
  bad="$(steps | jq -r 'select(.uses) | .uses' | grep -Ev "$ALLOWED_ACTIONS" || true)"
  echo "$bad"
  [ -z "$bad" ]
}

@test "R17: every run step is a mise task, the bootstrap, or listed plumbing" {
  bad=""
  while IFS= read -r cmd; do
    [[ "$cmd" =~ $ALLOWED_RUN ]] && continue
    ok=false
    for p in "${PLUMBING[@]}"; do [[ "$cmd" == "$p" ]] && ok=true; done
    $ok || bad+="$cmd"$'\n'
  done < <(steps | jq -r 'select(.run) | .run | rtrimstr("\n")')
  echo "$bad"
  [ -z "$bad" ]
}

@test "R17: every task CI runs exists" {
  tasks="$(mise tasks ls --json | jq -r '.[].name')"
  while IFS= read -r t; do
    grep -qx "$t" <<<"$tasks" || {
      echo "missing task: $t"
      return 1
    }
  done < <(steps | jq -r 'select(.run) | .run' | grep -oE 'mise run [a-z][a-z:-]*' | awk '{print $3}' | sort -u)
}

@test "R17: validate is the CI entry point and composes the Checks and tests" {
  deps="$(mise tasks info validate --json | jq -r '.depends[]' | sort | tr '\n' ' ')"
  [ "$deps" = "check check:apply check:commits check:repo test " ]
}
