#!/usr/bin/env bats
# Role-dependent template output. Templates are rendered with chezmoi using
# synthetic config data, never this Machine's own config.

load helpers

@test "the Ephemeral config enables only the dev Role" {
  cfg="$(role_config dev)"
  run env CODESPACES=true chezmoi --source "$REPO_ROOT" --config "$BATS_TEST_TMPDIR/none.yaml" \
    --no-tty execute-template --init <"$SOURCE_DIR/.chezmoi.yaml.tmpl"
  [ "$status" -eq 0 ]
  [ "$(yq -o json -I0 '.data.roles' <<<"$output")" = '["dev"]' ]
  [ "$(yq '.data.ephemeral' <<<"$output")" = true ]
  [ -n "$cfg" ]
}

@test "git: commit signing uses the configured 1Password signer" {
  RENDER_YQ='.data.opSshSignProgram = "/opt/test/op-ssh-sign"' \
    run render_with dev dot_config/git/config.tmpl
  [ "$status" -eq 0 ]
  [[ "$output" == *'program = "/opt/test/op-ssh-sign"'* ]]
  [[ "$output" == *"gpgsign = true"* ]]
}

@test "ssh: the 1Password agent is used only with the onepassword Role" {
  run render_with dev dot_ssh/private_config.tmpl
  [ "$status" -eq 0 ]
  [[ "$output" != *"1password"* && "$output" != *"1Password"* ]]
  run render_with dev,onepassword dot_ssh/private_config.tmpl
  [ "$status" -eq 0 ]
  [[ "$output" == *"IdentityAgent"* ]]
}

@test "a CI runner is detected as an Ephemeral machine" {
  run env -u CODESPACES -u REMOTE_CONTAINERS_IPC CI=true chezmoi --source "$REPO_ROOT" \
    --config "$BATS_TEST_TMPDIR/none.yaml" --no-tty execute-template --init <"$SOURCE_DIR/.chezmoi.yaml.tmpl"
  [ "$status" -eq 0 ]
  [ "$(yq '.data.ephemeral' <<<"$output")" = true ]
  [ "$(yq -o json -I0 '.data.roles' <<<"$output")" = '["dev"]' ]
}

@test "dotfiles-role-config rejects an unknown Role" {
  run "$REPO_ROOT/tools/bin/dotfiles-role-config" dev,gaming "$BATS_TEST_TMPDIR/cfg"
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown Role 'gaming'"* ]]
}

@test "dotfiles-role-config keeps Roles in the template's order" {
  cfg="$(role_config homelab,dev)"
  [ "$(yq -o json -I0 '.data.roles' "$cfg")" = '["dev","homelab"]' ]
  [ "$(yq '.data.ephemeral' "$cfg")" = false ]
}
