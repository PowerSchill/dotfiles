#!/usr/bin/env bats
# check:secrets must actually detect secrets: a repo .gitleaks.toml without
# `useDefault` replaces the default rules and silently finds nothing.

load helpers

@test "gitleaks flags a GitHub token with the repo's config" {
  # Built at runtime so this file does not contain a token-shaped string.
  local token
  token="ghp_$(printf 'aBcD3fGh1jKlMn0pQrStUvWxYz012345678%s' Z)"
  mkdir -p "$BATS_TEST_TMPDIR/scan"
  printf 'token = "%s"\n' "$token" >"$BATS_TEST_TMPDIR/scan/leak.txt"
  run gitleaks dir "$BATS_TEST_TMPDIR/scan" --config "$REPO_ROOT/.gitleaks.toml" --no-banner --redact
  [ "$status" -ne 0 ]
  [[ "$output" == *"leaks found: 1"* ]]
}
