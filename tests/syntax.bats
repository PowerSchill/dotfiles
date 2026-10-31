#!/usr/bin/env bats
# tools/checks/syntax.py: JSON, JSONC and TOML parsing.

load helpers

parse() {
  printf '%b' "$2" >"$BATS_TEST_TMPDIR/f"
  python3 -I "$REPO_ROOT/tools/checks/syntax.py" "$1:$BATS_TEST_TMPDIR/f"
}

@test "strict JSON rejects comments and trailing commas" {
  run parse json '// c\n{"a": 1}'
  [ "$status" -eq 1 ]
  run parse json '{"a": 1,}'
  [ "$status" -eq 1 ]
  run parse json '{"a": [1, 2]}'
  [ "$status" -eq 0 ]
}

@test "JSONC allows line and block comments and trailing commas" {
  run parse jsonc '// top\n{\n  /* block\n  comment */ "a": [1, 2,],\n}\n'
  [ "$status" -eq 0 ]
}

@test "JSONC keeps comment markers inside strings" {
  run parse jsonc '{"url": "https://example.com/a//b", "glob": "/*.txt"}'
  [ "$status" -eq 0 ]
}

@test "JSONC still rejects real syntax errors" {
  run parse jsonc '{"a": }'
  [ "$status" -eq 1 ]
  run parse jsonc '{"a": 1 /* unterminated'
  [ "$status" -eq 1 ]
}

@test "TOML" {
  run parse toml 'a = 1\n[b]\nc = "d"\n'
  [ "$status" -eq 0 ]
  run parse toml 'a = [1, 2\n'
  [ "$status" -eq 1 ]
}
