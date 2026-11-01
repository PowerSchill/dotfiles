#!/usr/bin/env bats
# R14: Checks cover config syntax, shell linting and formatting, and a dry-run apply.
# Test: a fixture with each kind of defect makes the matching Check fail, and a
# clean fixture passes. Fixtures live in the test's temp dir, never in the repo.

# Fixture scripts are written literally; their $1 must not expand here.
# shellcheck disable=SC2016

load helpers

setup() { cd "$REPO_ROOT" || return 1; }

fixture() {
  local name="$1"
  shift
  printf "%b" "$*" >"$BATS_TEST_TMPDIR/$name"
  echo "$BATS_TEST_TMPDIR/$name"
}

@test "R14: broken YAML fails check:syntax" {
  f="$(fixture bad.yaml 'a: [1, 2\nb: c\n')"
  run mise run -q check:syntax "$f"
  [ "$status" -ne 0 ]
}

@test "R14: broken JSON and TOML fail check:syntax; JSONC comments are allowed where expected" {
  run mise run -q check:syntax "$(fixture bad.json '{"a": 1,}')"
  [ "$status" -ne 0 ]
  run mise run -q check:syntax "$(fixture bad.toml 'a = [1, 2\n')"
  [ "$status" -ne 0 ]
  run mise run -q check:syntax "$(fixture ok.jsonc '// comment\n{"a": 1,}\n')"
  [ "$status" -eq 0 ]
}

@test "R14: a shellcheck error fails check:shellcheck" {
  f="$(fixture lint.sh '#!/usr/bin/env bash\nif [ -n $1 ]; then echo "$1"; fi\n')"
  run mise run -q check:shellcheck "$f"
  [ "$status" -ne 0 ]
  [[ "$output" == *"SC2070"* ]]
}

@test "R14: unformatted shell fails check:shfmt and fmt fixes it" {
  f="$(fixture fmt.sh '#!/usr/bin/env bash\nif true; then\n        echo hi\nfi\n')"
  run mise run -q check:shfmt "$f"
  [ "$status" -ne 0 ]
  run mise run -q fmt "$f"
  [ "$status" -eq 0 ]
  run mise run -q check:shfmt "$f"
  [ "$status" -eq 0 ]
}

@test "R14: a zsh syntax error fails check:zsh" {
  f="$(fixture bad.zsh 'if true; then\n  echo hi\n')"
  run mise run -q check:zsh "$f"
  [ "$status" -ne 0 ]
}

@test "R14: a broken shell template fails check:shellcheck" {
  f="$(fixture broken.sh.tmpl '#!/usr/bin/env bash\necho {{ .nope.missing \n')"
  run mise run -q check:shellcheck "$f"
  [ "$status" -ne 0 ]
}

@test "R14: shellcheck also lints template bodies gated on a Role" {
  f="$(fixture gated.sh.tmpl '#!/usr/bin/env bash\n{{ if .role.onepassword -}}\nif [ -n $1 ]; then echo "$1"; fi\n{{ end -}}\n')"
  run mise run -q check:shellcheck "$f"
  echo "$output"
  [ "$status" -ne 0 ]
  [[ "$output" == *"SC2070"* && "$output" == *"roles: all"* ]]
}

@test "R14: the dry-run apply passes on the repo" {
  run mise run -q check:apply
  echo "$output"
  [ "$status" -eq 0 ]
}

@test "R14: a template error fails the dry-run apply" {
  scratch_repo
  printf '{{ .nope.missing }}\n' >"home/dot_broken.tmpl"
  run mise run -q check:apply
  echo "$output"
  [ "$status" -ne 0 ]
  [[ "$output" == *"dot_broken.tmpl"* ]]
}
