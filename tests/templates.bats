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

# Simulated WSL: a fake `wslinfo` and a fake `dsregcmd.exe` (CRLF output, as
# Windows prints it) on PATH, then render the real config template.
init_data_with_dsregcmd() {
  local bin="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$bin"
  printf '#!/bin/sh\necho 2.4.0\n' >"$bin/wslinfo"
  printf '#!/bin/sh\nprintf "%%b" "%s"\n' "$1" >"$bin/dsregcmd.exe"
  chmod +x "$bin/wslinfo" "$bin/dsregcmd.exe"
  PATH="$bin:$PATH" CODESPACES=true chezmoi --source "$REPO_ROOT" --config "$BATS_TEST_TMPDIR/none.yaml" \
    --no-tty execute-template --init <"$SOURCE_DIR/.chezmoi.yaml.tmpl" | yq -o json '.data'
}

@test "enrollment: an Entra-joined, Intune-enrolled device is detected through dsregcmd" {
  run init_data_with_dsregcmd '| Device State |\r\n\r\n             AzureAdJoined : YES\r\n              DomainJoined : NO\r\n\r\n| Tenant Details |\r\n\r\n                TenantName : Contoso\r\n                  TenantId : 00000000-1111-2222-3333-444444444444\r\n                    MdmUrl : https://enrollment.manage.microsoft.com/x\r\n\r\n| User State |\r\n\r\n           WorkplaceJoined : NO\r\n'
  [ "$status" -eq 0 ]
  [ "$(jq -r .wsl <<<"$output")" = true ]
  [ "$(jq -r .isEntraIDJoined <<<"$output")" = true ]
  [ "$(jq -r .isIntuneJoined <<<"$output")" = true ]
  [ "$(jq -r .isADDomainJoined <<<"$output")" = false ]
  [ "$(jq -r .isEntraRegistered <<<"$output")" = false ]
  [ "$(jq -r .entraIDTenantName <<<"$output")" = Contoso ]
  [ "$(jq -r .entraIDTenantId <<<"$output")" = 00000000-1111-2222-3333-444444444444 ]
}

@test "enrollment: an unenrolled device has every flag false and no tenant" {
  run init_data_with_dsregcmd '             AzureAdJoined : NO\r\n              DomainJoined : NO\r\n           WorkplaceJoined : NO\r\n'
  [ "$status" -eq 0 ]
  [ "$(jq -r '[.isEntraIDJoined, .isIntuneJoined, .isADDomainJoined, .isEntraRegistered] | any' <<<"$output")" = false ]
  [ "$(jq -r .entraIDTenantName <<<"$output")" = "" ]
}

@test "isWork follows the work Role; githubUsername has a default" {
  cfg="$(role_config dev,work)"
  [ "$(yq '.data.isWork' "$cfg")" = true ]
  [ "$(yq '.data.githubUsername' "$cfg")" = PowerSchill ]
  cfg="$(role_config dev)"
  [ "$(yq '.data.isWork' "$cfg")" = false ]
}

@test "the PowerShell chezmoi template renders with the new data" {
  run render_with dev,work dot_config/powershell/chezmoi.ps1.tmpl
  [ "$status" -eq 0 ]
  [[ "$output" == *'CHEZMOI_GITHUB_USERNAME = "PowerSchill"'* ]]
  [[ "$output" == *'CHEZMOI_IS_WORK = "true"'* ]]
}
