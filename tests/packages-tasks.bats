#!/usr/bin/env bats
# dotfiles-packages and dotfiles-package-audit. brew is stubbed and the audit reads
# a fixture API, so nothing here installs, removes or downloads anything.

# Stub bodies are expanded when the stub runs, not here.
# shellcheck disable=SC2016

bats_require_minimum_version 1.5.0

load helpers

setup() {
  BIN="$BATS_TEST_TMPDIR/bin"
  export HOME="$BATS_TEST_TMPDIR/home" BREW_LOG="$BATS_TEST_TMPDIR/brew.log"
  export DOTFILES_HOMEBREW_LOCATIONS="$BATS_TEST_TMPDIR/none/brew"
  mkdir -p "$BIN" "$HOME/.local/bin"
  printf '#!/bin/sh\nprintf "%%s\\n" "$*" >>"$BREW_LOG"\n' >"$BIN/brew"
  chmod +x "$BIN/brew"
  printf 'brew "bat"\nbrew "zsh"\nbrew "fd"\ncask "zed"\n' >"$HOME/.Brewfile"
  PKG="$REPO_ROOT/tools/bin/dotfiles-packages"
  AUDIT="$REPO_ROOT/tools/bin/dotfiles-package-audit"
}

stub() {
  printf '#!/bin/sh\n%s\n' "$2" >"$BIN/$1"
  chmod +x "$BIN/$1"
}

@test "packages:check reads ~/.Brewfile" {
  PATH="$BIN:$PATH" run "$PKG" check
  [ "$status" -eq 0 ]
  grep -qx "bundle check --verbose --file=$HOME/.Brewfile" "$BREW_LOG"
}

@test "packages:cleanup only lists without --yes" {
  PATH="$BIN:$PATH" run "$PKG" cleanup
  [ "$status" -eq 0 ]
  [[ "$output" == *"listing only"* ]]
  grep -qx "bundle cleanup --file=$HOME/.Brewfile" "$BREW_LOG"
  run ! grep -q -- --force "$BREW_LOG"
}

@test "packages:cleanup uninstalls only with --yes" {
  PATH="$BIN:$PATH" run "$PKG" cleanup --yes
  [ "$status" -eq 0 ]
  grep -qx "bundle cleanup --force --file=$HOME/.Brewfile" "$BREW_LOG"
}

@test "packages: a missing Brewfile is explained" {
  rm "$HOME/.Brewfile"
  PATH="$BIN:$PATH" run "$PKG" check
  [ "$status" -ne 0 ]
  [[ "$output" == *"Apply writes it"* ]]
}

@test "packages: an unknown command prints usage" {
  PATH="$BIN:$PATH" run "$PKG" nonsense
  [ "$status" -eq 2 ]
  [[ "$output" == *"dotfiles-packages leftovers"* ]]
}

@test "packages:leftovers reports native copies, and never the login shell" {
  stub uname 'echo Linux'
  stub dpkg-query 'case "$*" in *" bat"|*" fd-find"|*" zsh") echo "install ok installed" ;; esac'
  ln -s /usr/bin/batcat "$HOME/.local/bin/bat"
  PATH="$BIN:$PATH" run "$PKG" leftovers
  echo "$output"
  [ "$status" -eq 0 ]
  [[ "$output" == *"apt: bat (Homebrew installs bat)"* ]]
  [[ "$output" == *"apt: fd-find (Homebrew installs fd)"* ]]
  [[ "$output" == *"link: ~/.local/bin/bat -> /usr/bin/batcat"* ]]
  [[ "$output" != *"apt: zsh"* ]]
  [[ "$output" == *"nothing was removed"* ]]
  [ ! -e "$BREW_LOG" ]
}

@test "packages:leftovers says so on macOS" {
  stub uname 'echo Darwin'
  PATH="$BIN:$PATH" run "$PKG" leftovers
  [ "$status" -eq 0 ]
  [[ "$output" == *"only Linux"* ]]
}

# A fixture API: bat has every bottle, ghostly is disabled, mac-tool has no Linux bottle.
fixture_api() {
  API_DIR="$BATS_TEST_TMPDIR/api"
  mkdir -p "$API_DIR"
  cat >"$API_DIR/formula.json" <<'JSON'
[
  {"name": "bat", "aliases": ["batcat"], "bottle": {"stable": {"files": {"arm64_tahoe": {}, "x86_64_linux": {}, "arm64_linux": {}}}}},
  {"name": "noarch", "bottle": {"stable": {"files": {"all": {}}}}},
  {"name": "ghostly", "disabled": true, "bottle": {"stable": {"files": {"all": {}}}}},
  {"name": "mac-tool", "bottle": {"stable": {"files": {"arm64_tahoe": {}}}}}
]
JSON
  echo '[{"token": "zed"}, {"token": "gone", "disabled": true}]' >"$API_DIR/cask.json"
  export DOTFILES_BREW_API="file://$API_DIR"
}

audit() {
  printf '%s' "$1" >"$BATS_TEST_TMPDIR/packages.json"
  run python3 -I "$AUDIT" "$BATS_TEST_TMPDIR/packages.json"
}

@test "packages:audit passes when everything is available" {
  fixture_api
  audit '{"packages":{"homebrew":{"brews":{"base":[{"name":"bat"},{"name":"batcat"},{"name":"noarch"},{"name":"mac-tool","platforms":["macos"]}]},"casks":{"base":[{"name":"zed"}]}}}}'
  echo "$output"
  [ "$status" -eq 0 ]
  [[ "$output" == *"0 problem(s)"* ]]
}

@test "packages:audit reports missing, disabled and bottle-less entries" {
  fixture_api
  audit '{"packages":{"homebrew":{"brews":{"base":[{"name":"nope"},{"name":"ghostly"},{"name":"mac-tool"}]},"casks":{"gui":[{"name":"absent"},{"name":"gone"}]}}}}'
  echo "$output"
  [ "$status" -eq 1 ]
  [[ "$output" == *"brews.base: nope: no such formula"* ]]
  [[ "$output" == *"brews.base: ghostly: disabled by Homebrew"* ]]
  [[ "$output" == *"mac-tool: no x86_64_linux or arm64_linux bottle"* ]]
  [[ "$output" == *"casks.gui: absent: no such cask"* ]]
  [[ "$output" == *"casks.gui: gone: disabled by Homebrew"* ]]
}

@test "packages:audit lists tapped entries as not checked" {
  fixture_api
  audit '{"packages":{"homebrew":{"brews":{"base":[{"name":"u/t/thing"}]}}}}'
  [ "$status" -eq 0 ]
  [[ "$output" == *"not checked (tapped): u/t/thing"* ]]
}

@test "packages:audit explains an unreachable API" {
  export DOTFILES_BREW_API="file://$BATS_TEST_TMPDIR/absent"
  audit '{"packages":{"homebrew":{}}}'
  [ "$status" -eq 2 ]
  [[ "$output" == *"could not reach"* ]]
}
