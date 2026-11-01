#!/usr/bin/env bats
# home/dot_config/shell/functions/log.sh: the sanitizer and the guarantees in
# docs/logging.md. Each case runs in a fresh `sh` so nothing leaks between tests.

# shellcheck disable=SC2016  # snippets are single-quoted on purpose: the inner sh expands them
load helpers

LOG_SH="$REPO_ROOT/home/dot_config/shell/functions/log.sh"

# Run a snippet of shell with log.sh sourced and a fixed environment.
run_log() {
  run env -u LOG_TAG -u LOG_FILE LOG_COLOR=never LOG_JOURNAL=never LOG_TIMESTAMP=T \
    sh -c ". '$LOG_SH'; $1"
}

@test "ESC and BEL are stripped from messages" {
  run_log 'log_info "$(printf "a\033[31mred\007b")"'
  [ "$status" -eq 0 ]
  [[ "$output" == *"a[31mredb" ]]
  [[ "$output" != *$'\033'* ]]
  [[ "$output" != *$'\007'* ]]
}

@test "ESC and BEL are stripped from log_data payloads" {
  run_log 'printf "x\033[31my\007z\n" | log_data INFO hdr'
  [ "$status" -eq 0 ]
  [[ "$output" != *$'\033'* ]]
  [[ "$output" != *$'\007'* ]]
  [[ "$output" == *"x[31myz"* ]]
}

@test "CR and LF are escaped so one call is one line" {
  run_log 'log_info "$(printf "one\ntwo\rthree")"'
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 1 ]
  [[ "$output" == *'one\ntwo\rthree' ]]
}

@test "format specifiers in messages are printed literally" {
  run_log 'log_info "%s %n %x"'
  [[ "$output" == *"%s %n %x" ]]
}

@test "messages are truncated at LOG_MAX_BYTES with a marker" {
  run_log 'LOG_MAX_BYTES=20 log_info "$(printf "y%.0s" $(seq 100))"'
  [[ "$output" == *"...[truncated]" ]]
}

@test "invalid tags are dropped and valid ones rendered" {
  for bad in -flag .hidden "has space" "$(printf 'x%.0s' $(seq 33))"; do
    run env LOG_TAG="$bad" LOG_COLOR=never LOG_JOURNAL=never sh -c ". '$LOG_SH'; log_info m"
    [[ "$output" != *"["* ]]
  done
  run env LOG_TAG=ok.tag-1 LOG_COLOR=never LOG_JOURNAL=never sh -c ". '$LOG_SH'; log_info m"
  [[ "$output" == *"[ok.tag-1] m" ]]
}

@test "kinds render their own label at INFO priority" {
  run_log 'log_state a; log_result b; log_hint c; log_step d'
  [[ "${lines[0]}" == *"STATE  a" ]]
  [[ "${lines[1]}" == *"RESULT b" ]]
  [[ "${lines[2]}" == *"HINT   c" ]]
  [[ "${lines[3]}" == *"STEP   d" ]]
}

@test "warn and error go to stderr, info to stdout" {
  run sh -c ". '$LOG_SH'; log_info out; log_warn err 2>/dev/null"
  [[ "$output" == *"out" ]]
  [[ "$output" != *"err" ]]
  run sh -c ". '$LOG_SH'; log_info out >/dev/null; log_warn err"
  [[ "$output" == *"WARN   err" ]]
  [[ "$output" != *"out" ]]
}

@test "LOG_LEVEL filters below the minimum severity" {
  run_log 'log_debug hidden; LOG_LEVEL=DEBUG log_debug shown'
  [[ "$output" != *hidden* ]]
  [[ "$output" == *shown* ]]
}

@test "JSON mode emits keys in order with an escaped data field" {
  run env LOG_FORMAT=json LOG_TAG=t LOG_JOURNAL=never sh -c ". '$LOG_SH'; printf 'a\nb\n' | log_data INFO hdr"
  [ "$status" -eq 0 ]
  [[ "$output" == '{"timestamp":"'*'","level":"INFO","kind":"INFO","tag":"t","message":"hdr","data":'* ]]
}

@test "LOG_FILE needs a lifecycle, rejects symlinks, and uses ISO timestamps" {
  f="$BATS_TEST_TMPDIR/a.log"
  run env LOG_FILE="$f" LOG_TO_STDIO=0 LOG_JOURNAL=never sh -c ". '$LOG_SH'; log_info nope"
  [ ! -e "$f" ]
  run env LOG_FILE="$f" LOG_FILE_TTL_DAYS=1 LOG_TO_STDIO=0 LOG_JOURNAL=never sh -c ". '$LOG_SH'; log_state hi"
  [[ "$(cat "$f")" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z\ STATE\ \ hi ]]
  ln -s "$f" "$BATS_TEST_TMPDIR/link.log"
  run env LOG_FILE="$BATS_TEST_TMPDIR/link.log" LOG_FILE_TTL_DAYS=1 LOG_TO_STDIO=0 LOG_JOURNAL=never sh -c ". '$LOG_SH'; log_state linked"
  [ "$(wc -l <"$f")" -eq 1 ]
}

@test "banners fall back to ASCII off a TTY" {
  run_log 'LOG_BANNER_STYLE=box log_banner Title'
  [[ "$output" == *"===="* ]]
  [[ "$output" != *"┌"* ]]
}

@test "log.sh sources cleanly under set -euo pipefail in bash and sh" {
  run bash -c "set -euo pipefail; . '$LOG_SH'; log_state ok"
  [ "$status" -eq 0 ]
  run sh -c "set -eu; . '$LOG_SH'; log_state ok"
  [ "$status" -eq 0 ]
}
