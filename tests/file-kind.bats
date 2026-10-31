#!/usr/bin/env bats
# tools/checks/lib.bash: which Check handles which file.

load helpers

setup() {
  # shellcheck source=tools/checks/lib.bash
  source "$REPO_ROOT/tools/checks/lib.bash"
  cd "$BATS_TEST_TMPDIR" || return 1
}

kind() {
  mkdir -p "$(dirname "$1")"
  printf '%b' "${2:-}" >"$1"
  file_kind "$1"
}

@test "the shebang wins over the extension" {
  [ "$(kind zshy.sh '#!/usr/bin/env zsh\n')" = zsh ]
  [ "$(kind plain '#!/bin/sh\n')" = shell ]
  [ "$(kind tool '#!/usr/bin/env bash\n')" = shell ]
}

@test "extensions and zsh dotfile names" {
  [ "$(kind a.sh 'echo\n')" = shell ]
  [ "$(kind t.bats '')" = shell ]
  [ "$(kind f.zsh '')" = zsh ]
  [ "$(kind dot_zshrc '')" = zsh ]
}

@test "templates are told apart from plain files" {
  [ "$(kind run_x.sh.tmpl '')" = shell-template ]
  [ "$(kind dot_zshrc.tmpl '')" = zsh-template ]
  [ "$(kind f.zsh.tmpl '')" = zsh-template ]
  [ -z "$(kind dot_gitconfig.tmpl '')" ]
}

@test "chezmoi special files are left to the dry-run apply" {
  [ -z "$(kind .chezmoiexternal.yaml 'a: 1\n')" ]
  [ -z "$(kind .chezmoiignore.tmpl '')" ]
}

@test "config formats, with JSONC by path" {
  [ "$(kind a.yaml '')" = yaml ]
  [ "$(kind a.yml '')" = yaml ]
  [ "$(kind a.toml '')" = toml ]
  [ "$(kind a.json '{}')" = json ]
  [ "$(kind a.jsonc '{}')" = jsonc ]
  [ "$(kind home/dot_config/zed/settings.json '{}')" = jsonc ]
  [ "$(kind "home/private_Library/private_Application Support/private_Cursor/User/settings.json" '{}')" = jsonc ]
}

@test "unknown files are ignored" {
  [ -z "$(kind README.md '# hi\n')" ]
  [ -z "$(kind missing-file-that-is-a-dir/)" ] || true
}
