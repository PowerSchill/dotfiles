#!/usr/bin/env bats
# R3: versions are pinned or explicitly "latest", and pinned versions can be
# bumped by automated update tooling.
# Test: every Toolchain version is exact (latest only in mise.full.toml), the
# Renovate config is valid, and Renovate proposes an update for a fixture pinned
# to an old version. Renovate runs through mise with a pinned node and renovate.

load helpers

# Renovate's own runtime, pinned here (renovate 44 requires node ^24.11).
NODE_VERSION="24.22.2"
RENOVATE_VERSION="44.198.3"

renovate() {
  MISE_YES=1 mise x "node@$NODE_VERSION" -- npx --yes "--package=renovate@$RENOVATE_VERSION" "$@"
}

@test "R3: mise.toml pins exact versions only" {
  tools="$(sed -n '/^\[tools\]/,/^\[/{/=/p;}' "$REPO_ROOT/mise.toml")"
  loose="$(grep -vE '= "[0-9]+\.[0-9]+\.[0-9]+"( *#.*)?$' <<<"$tools" || true)"
  echo "$loose"
  [ -n "$tools" ]
  [ -z "$loose" ]
}

@test "R3: mise.full.toml pins exact versions or says latest" {
  tools="$(sed -n '/^\[tools\]/,/^\[/{/=/p;}' "$REPO_ROOT/mise.full.toml")"
  loose="$(grep -vE '= "([0-9]+\.[0-9]+\.[0-9]+|latest)"( *#.*)?$' <<<"$tools" || true)"
  echo "$loose"
  [ -z "$loose" ]
}

@test "R3: the Renovate config is valid" {
  cd "$REPO_ROOT" || return 1
  run renovate renovate-config-validator --strict renovate.json
  echo "$output"
  [ "$status" -eq 0 ]
}

@test "R3: Renovate proposes a bump for an outdated pin" {
  fixture="$BATS_TEST_TMPDIR/fixture"
  mkdir -p "$fixture"
  cp "$REPO_ROOT/renovate.json" "$fixture/"
  printf '[tools]\njq = "1.7.0"\n' >"$fixture/mise.toml"
  (cd "$fixture" && git init -q -b main && git add -A && git commit -q -m "test: fixture")
  cd "$fixture" || return 1
  # Renovate looks the tool up through the GitHub API, which needs a token.
  token="${GITHUB_COM_TOKEN:-${CHEZMOI_GITHUB_ACCESS_TOKEN:-$(gh auth token 2>/dev/null || true)}}"
  [ -n "$token" ] || skip "needs a GitHub token (CI provides one; locally, gh auth login)"
  run env LOG_LEVEL=debug RENOVATE_CONFIG_FILE=renovate.json GITHUB_COM_TOKEN="$token" \
    MISE_TRUSTED_CONFIG_PATHS="$fixture" \
    mise x "node@$NODE_VERSION" -- npx --yes "renovate@$RENOVATE_VERSION" --platform=local --dry-run=lookup
  [ "$status" -eq 0 ]
  [[ "$output" == *'"depName": "jq"'* ]]
  [[ "$output" == *'"newVersion": "1.8'* ]]
}
