#!/usr/bin/env bats
# home/dot_config/shell/functions/homebrew.sh, with every system command stubbed:
# these tests never install Homebrew. tests/acceptance installs it for real.

# Stub bodies are expanded when the stub runs, not here.
# shellcheck disable=SC2016

load helpers

setup() {
  BIN="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$BIN"
  export DOTFILES_HOMEBREW_LOCATIONS="$BATS_TEST_TMPDIR/none/brew"
  # Not the real prefix: the acceptance container has a writable one.
  export DOTFILES_HOMEBREW_PREFIX="$BATS_TEST_TMPDIR/none"
  export DOTFILES_CONTAINER_MARKERS="$BATS_TEST_TMPDIR/not-a-container"
  stub id 'echo 1000'
  stub uname 'case "$1" in -s) echo Linux ;; -m) echo x86_64 ;; -r) echo 6.1.0-generic ;; esac'
  stub getconf 'echo glibc 2.39'
  stub sudo 'exit 0'
}

stub() {
  printf '#!/bin/sh\n%s\n' "$2" >"$BIN/$1"
  chmod +x "$BIN/$1"
}

# Run a snippet with homebrew.sh loaded and only the stubs ahead of the system PATH.
hb() {
  run env PATH="$BIN:/usr/bin:/bin" bash -c "
    . '$SOURCE_DIR/dot_config/shell/functions/log.sh'
    . '$SOURCE_DIR/dot_config/shell/functions/homebrew.sh'
    $1"
}

@test "platform: Apple Silicon on macOS 15 and Linux with glibc are served" {
  hb homebrew_platform_problem
  [ "$status" -eq 0 ] && [ -z "$output" ]
  stub uname 'case "$1" in -s) echo Darwin ;; -m) echo arm64 ;; esac'
  stub sw_vers 'echo 15.1'
  hb homebrew_platform_problem
  [ "$status" -eq 0 ] && [ -z "$output" ]
}

@test "platform: ARM64 Linux and WSL 2 are served" {
  stub uname 'case "$1" in -s) echo Linux ;; -m) echo aarch64 ;; -r) echo 5.15.0-microsoft-standard-WSL2 ;; esac'
  hb homebrew_platform_problem
  [ "$status" -eq 0 ] && [ -z "$output" ]
}

@test "platform: Intel macOS is not served" {
  stub uname 'case "$1" in -s) echo Darwin ;; -m) echo x86_64 ;; esac'
  hb homebrew_platform_problem
  [[ "$output" == *"Intel macOS is Homebrew Tier 3"* ]]
}

@test "platform: macOS older than 15 is not served" {
  stub uname 'case "$1" in -s) echo Darwin ;; -m) echo arm64 ;; esac'
  stub sw_vers 'echo 14.7.1'
  hb homebrew_platform_problem
  [[ "$output" == *"macOS 14 is Homebrew Tier 3"* ]]
}

@test "platform: ARM32 Linux is not served" {
  stub uname 'case "$1" in -s) echo Linux ;; -m) echo armv7l ;; esac'
  hb homebrew_platform_problem
  [[ "$output" == *"armv7l is not a Homebrew platform"* ]]
}

@test "platform: WSL 1 is not served" {
  stub uname 'case "$1" in -s) echo Linux ;; -m) echo x86_64 ;; -r) echo 4.4.0-19041-Microsoft ;; esac'
  hb homebrew_platform_problem
  [[ "$output" == *"WSL 1 is Homebrew Tier 3"* ]]
}

@test "platform: Linux without glibc is not served" {
  stub getconf 'exit 1'
  hb homebrew_platform_problem
  [[ "$output" == *"needs glibc"* ]]
}

@test "prepare: an unsupported platform warns and skips, without installing" {
  stub uname 'case "$1" in -s) echo Linux ;; -m) echo armv7l ;; esac'
  stub curl 'echo curl-ran >&2; exit 1'
  hb homebrew_prepare
  [ "$status" -ne 0 ]
  [[ "$output" == *"Skipping Homebrew"* && "$output" != *curl-ran* ]]
}

@test "prepare: root outside a container warns and skips" {
  stub id 'echo 0'
  hb homebrew_prepare
  [ "$status" -ne 0 ]
  [[ "$output" == *"refuses to run as root"* ]]
}

@test "prepare: root inside a container uses Homebrew" {
  stub id 'echo 0'
  stub brew 'echo "export FROM_SHELLENV=1"'
  touch "$BATS_TEST_TMPDIR/marker"
  DOTFILES_CONTAINER_MARKERS="$BATS_TEST_TMPDIR/marker" hb 'homebrew_prepare && echo "ready $FROM_SHELLENV"'
  [ "$status" -eq 0 ]
  [[ "$output" == *"ready 1"* ]]
}

@test "prepare: an installed brew needs no sudo and no download" {
  stub brew 'echo "export FROM_SHELLENV=1"'
  stub sudo 'echo sudo-ran >&2; exit 1'
  stub curl 'echo curl-ran >&2; exit 1'
  hb 'homebrew_prepare && echo "ready $FROM_SHELLENV"'
  [ "$status" -eq 0 ]
  [[ "$output" == *"ready 1"* && "$output" != *sudo-ran* && "$output" != *curl-ran* ]]
}

@test "prepare: no brew and no sudo warns and skips" {
  stub sudo 'exit 1'
  stub curl 'echo curl-ran >&2; exit 1'
  hb 'homebrew_prepare </dev/null'
  [ "$status" -ne 0 ]
  [[ "$output" == *"needs sudo"* && "$output" != *curl-ran* ]]
}

@test "install: the pinned commit is downloaded, verified and run non-interactively" {
  local url="$BATS_TEST_TMPDIR/url" ran="$BATS_TEST_TMPDIR/ran" script="$BATS_TEST_TMPDIR/payload"
  printf 'echo "NONINTERACTIVE=$NONINTERACTIVE" >"%s"\n' "$ran" >"$script"
  stub curl "printf '%s\n' \"\$2\" >'$url'; cp '$script' \"\$4\""
  hb "HOMEBREW_INSTALL_SHA256=\"\$(homebrew_sha256 '$script')\"; homebrew_install"
  echo "$output"
  [ "$status" -eq 0 ]
  grep -qx 'https://raw.githubusercontent.com/Homebrew/install/[0-9a-f]\{40\}/install.sh' "$url"
  grep -q 'NONINTERACTIVE=1' "$ran"
}

@test "install: a checksum mismatch stops before the installer runs" {
  local ran="$BATS_TEST_TMPDIR/ran" script="$BATS_TEST_TMPDIR/payload"
  printf 'touch "%s"\n' "$ran" >"$script"
  stub curl "cp '$script' \"\$4\""
  hb "homebrew_install; echo not-reached"
  [ "$status" -ne 0 ]
  [[ "$output" == *"checksum mismatch"* && "$output" != *not-reached* ]]
  [ ! -e "$ran" ]
}

@test "install: a failed download fails" {
  stub curl 'exit 22'
  hb "homebrew_install; echo not-reached"
  [ "$status" -eq 22 ]
  [[ "$output" != *not-reached* ]]
}

@test "shell: homebrew-env puts Homebrew's bin on PATH and names the global Brewfile" {
  run env -i HOME="$BATS_TEST_TMPDIR" PATH=/usr/bin:/bin sh -c \
    ". '$SOURCE_DIR/dot_config/shell/homebrew-env.sh'; echo \"\$HOMEBREW_BUNDLE_FILE_GLOBAL\""
  [ "$status" -eq 0 ]
  [ "$output" = "$BATS_TEST_TMPDIR/.Brewfile" ]
}

@test "shell: .zshrc and .bashrc both load homebrew-env" {
  grep -q 'shell/homebrew-env.sh' "$SOURCE_DIR/dot_zshrc.tmpl"
  grep -q 'shell/homebrew-env.sh' "$SOURCE_DIR/dot_bashrc"
}
