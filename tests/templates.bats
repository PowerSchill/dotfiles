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

# Render the real config template without a TTY, as a script or agent would run
# `chezmoi init`, for a Machine that already has a config.
init_data_keeping() {
  local cfg="$BATS_TEST_TMPDIR/chezmoi-saved.yaml"
  cat >"$cfg" <<'EOF'
data:
  email: "saved@example.com"
  role:
    dev: true
    gui: false
    work: true
    personal: false
    security: true
    onepassword: true
    homelab: false
EOF
  env -u CI -u CODESPACES -u REMOTE_CONTAINERS_IPC chezmoi --source "$REPO_ROOT" --config "$cfg" \
    --no-tty execute-template --init <"$SOURCE_DIR/.chezmoi.yaml.tmpl" | yq -o json '.data'
}

@test "a non-interactive init keeps this Machine's Roles and email" {
  case "$(id -un)" in root | ubuntu | vagrant | vscode) skip "this username is detected as Ephemeral" ;; esac
  run init_data_keeping
  [ "$status" -eq 0 ]
  [ "$(jq -c .roles <<<"$output")" = '["dev","work","security","onepassword"]' ]
  [ "$(jq -r .email <<<"$output")" = saved@example.com ]
}

@test "git: delta options render on their own lines" {
  run render_with dev dot_config/git/config.tmpl
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" >"$BATS_TEST_TMPDIR/gitconfig"
  [ "$(git config -f "$BATS_TEST_TMPDIR/gitconfig" --get delta.side-by-side)" = true ]
  [[ "$(git config -f "$BATS_TEST_TMPDIR/gitconfig" --get delta.features)" == catppuccin-* ]]
}

@test "ssh: agent forwarding is off by default" {
  run render_with dev,onepassword dot_ssh/private_config.tmpl
  [ "$status" -eq 0 ]
  [[ "$output" == *"ForwardAgent no"* ]]
  [[ "$output" != *"ForwardAgent yes"$'\n'* ]]
}

@test "packages: a failed brew bundle fails the darwin install script" {
  local cfg bin="$BATS_TEST_TMPDIR/bin" home="$BATS_TEST_TMPDIR/home"
  mkdir -p "$bin" "$home"
  printf '#!/bin/sh\nexit 1\n' >"$bin/brew"
  chmod +x "$bin/brew"
  cfg="$(role_config dev)"
  chezmoi --source "$REPO_ROOT" --config "$cfg" --override-data '{"chezmoi":{"os":"darwin"}}' --no-tty \
    execute-template <"$SOURCE_DIR/.chezmoiscripts/darwin/run_onchange_before_install-packages.sh.tmpl" \
    >"$BATS_TEST_TMPDIR/install.sh"
  run env HOME="$home" PATH="$bin:$PATH" bash "$BATS_TEST_TMPDIR/install.sh"
  [ "$status" -ne 0 ]
  [[ "$output" != *"brew bundle complete"* ]]
}

@test "packages: every Linux install script stops on the first failure" {
  local f
  for f in before_10_install-packages before_15_install-wezterm before_30_install-op; do
    grep -q '^set -euo pipefail$' "$SOURCE_DIR/.chezmoiscripts/linux/run_onchange_$f.sh.tmpl"
  done
}

# A fake home with the real shell config and a stub Oh My Zsh that defines the
# aliases the real one does. Prints the `ls` alias and a P10k color variable.
zsh_probe() {
  local home="$BATS_TEST_TMPDIR/zhome" cfg
  mkdir -p "$home/.config/zsh/functions" "$home/.oh-my-zsh" "$home/bin"
  # .zshrc runs fastfetch, which looks up the public IP. Not in a test.
  printf '#!/bin/sh\n' >"$home/bin/fastfetch"
  chmod +x "$home/bin/fastfetch"
  cfg="$(role_config dev)"
  printf "alias ls='ls -G'\n" >"$home/.oh-my-zsh/oh-my-zsh.sh"
  local f
  for f in "$SOURCE_DIR"/dot_config/zsh/*.zsh; do cp "$f" "$home/.config/zsh/"; done
  chezmoi --source "$REPO_ROOT" --config "$cfg" --no-tty execute-template \
    <"$SOURCE_DIR/dot_config/zsh/oh-my-zsh.zsh.tmpl" >"$home/.config/zsh/oh-my-zsh.zsh"
  chezmoi --source "$REPO_ROOT" --config "$cfg" --no-tty execute-template \
    <"$SOURCE_DIR/dot_zshrc.tmpl" >"$home/.zshrc"
  # shellcheck disable=SC2016 # expanded by the inner zsh
  env -i HOME="$home" TERM=dumb PATH="$1" zsh -ic \
    'print -r -- "LS=${aliases[ls]}"; print -r -- "COLOR=${POWERLEVEL9K_RULER_FOREGROUND-unset}"' </dev/null 2>/dev/null
}

@test "zsh: this repo's aliases override Oh My Zsh when eza is installed" {
  local bin="$BATS_TEST_TMPDIR/eza-bin"
  mkdir -p "$bin"
  printf '#!/bin/sh\n' >"$bin/eza"
  chmod +x "$bin/eza"
  run zsh_probe "$bin:$PATH"
  [[ "$output" == *"LS=eza --icons=auto"* ]]
  [[ "$output" != *"--color=always"* ]]
}

@test "zsh: ls keeps working without eza" {
  # Sourced alone: .zshrc puts Homebrew on PATH, which can hold a real eza.
  local bin="$BATS_TEST_TMPDIR/no-eza-bin"
  mkdir -p "$bin"
  run env -i PATH="$bin" "$(command -v zsh)" -fc \
    "alias ls='ls -G'; source '$SOURCE_DIR/dot_config/zsh/aliases.zsh'; print -r -- \"LS=\${aliases[ls]}\""
  [[ "$output" == *"LS=ls -G"* ]]
}

@test "zsh: vi mode is selected before Oh My Zsh binds its completion widgets" {
  local vi omz
  vi="$(grep -n '^ *bindkey -v$' "$SOURCE_DIR/dot_zshrc.tmpl" | head -1 | cut -d: -f1)"
  # shellcheck disable=SC2016 # a literal $ZSH_CONFIG_DIR in the file
  omz="$(grep -n 'source "$ZSH_CONFIG_DIR/oh-my-zsh.zsh"' "$SOURCE_DIR/dot_zshrc.tmpl" | cut -d: -f1)"
  [ -n "$vi" ] && [ -n "$omz" ] && [ "$vi" -lt "$omz" ]
}

@test "zsh: prompt colors are left to ~/.p10k.zsh" {
  run zsh_probe "$PATH"
  [[ "$output" == *"COLOR=unset"* ]]
}

@test "scripts: the package removal script starts with its shebang, also as root" {
  local script="$SOURCE_DIR/.chezmoiscripts/linux/run_onchange_linux_after_30_remove-packages.sh.tmpl"
  local cfg
  cfg="$(role_config dev)"
  yq -i '.data.osid = "linux-ubuntu"' "$cfg"
  run bash -c "sed 's/eq .chezmoi.username \"root\"/true/' '$script' |
    chezmoi --source '$REPO_ROOT' --config '$cfg' --no-tty execute-template"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "#!/bin/bash" ]
  [[ "$output" != *"sudo "* ]]
}

@test "op: Debian installs the CLI from apt, never the desktop tarball" {
  RENDER_YQ='.data.osid = "linux-debian"' run render_with onepassword .chezmoiscripts/linux/run_onchange_before_30_install-op.sh.tmpl
  [ "$status" -eq 0 ]
  [[ "$output" == *"packages+=(1password-cli)"* ]]
  [[ "$output" == *"apt-get install"* ]]
  [[ "$output" != *"packages+=(1password)"* ]]
  [[ "$output" != *"1password-latest.tar.gz"* ]]
}

@test "op: a gui machine also installs the desktop app" {
  RENDER_YQ='.data.osid = "linux-fedora"' run render_with onepassword,gui .chezmoiscripts/linux/run_onchange_before_30_install-op.sh.tmpl
  [ "$status" -eq 0 ]
  [[ "$output" == *"packages+=(1password)"* ]]
  [[ "$output" == *"dnf -y install"* ]]
}

@test "roles: a saved Role survives init unless DOTFILES_ROLE_CHANGE names it" {
  case "$(id -un)" in root | ubuntu | vagrant | vscode) skip "this username is detected as Ephemeral" ;; esac
  local cfg
  cfg="$(role_config dev)"
  yq -i '.data.role.security = false' "$cfg"
  render() {
    env -u CI -u CODESPACES -u REMOTE_CONTAINERS_IPC chezmoi --source "$REPO_ROOT" --config "$cfg" \
      --persistent-state "$(dirname "$cfg")/state.boltdb" \
      --destination "$BATS_TEST_TMPDIR/fakehome" --no-tty \
      execute-template --init --promptBool security=true <"$SOURCE_DIR/.chezmoi.yaml.tmpl" | yq -r '.data.role.security'
  }
  [ "$(render)" = false ]
  export DOTFILES_ROLE_CHANGE=security
  [ "$(render)" = true ]
}

@test "documents: one source directory per target" {
  local src="$BATS_TEST_TMPDIR/docsrc"
  mkdir -p "$src"
  cp -R "$SOURCE_DIR"/*Documents "$src/"
  run chezmoi --source "$src" --config "$BATS_TEST_TMPDIR/none.yaml" \
    --persistent-state "$BATS_TEST_TMPDIR/docs.boltdb" --destination "$BATS_TEST_TMPDIR/fakehome" managed
  [ "$status" -eq 0 ]
  [[ "$output" == *"Microsoft.PowerShell_profile.ps1"* ]]
}

@test "claude: settings define the .env block, reading the event from stdin" {
  local settings="$SOURCE_DIR/dot_claude/private_settings.json" cmd
  cmd="$(jq -r '.hooks.PreToolUse[] | select(.matcher == "Read") | .hooks[0].command' "$settings")"
  run bash -c "$cmd" <<<'{"tool_input":{"file_path":"/x/.env"}}'
  [ "$status" -eq 2 ]
  run bash -c "$cmd" <<<'{"tool_input":{"file_path":"/x/notes.txt"}}'
  [ "$status" -eq 0 ]
}

@test "claude: the status line calls the installed binary, not bunx" {
  run jq -r '.statusLine.command' "$SOURCE_DIR/dot_claude/private_settings.json"
  # shellcheck disable=SC2016 # the literal text in the settings file
  [ "$output" = '$HOME/.bun/bin/ccstatusline' ]
}

@test "claude: ccstatusline installs where the status line calls it" {
  # shellcheck disable=SC2016 # the literal text in the script
  grep -q '^BUN_INSTALL="$HOME/.bun" bun install -g ccstatusline@' \
    "$SOURCE_DIR/.chezmoiscripts/darwin/run_onchange_after_install-ccstatusline.sh.tmpl"
}

@test "lazygit: force push asks first and keeps the pre-push hook" {
  run yq -r '.customCommands[] | select(.key == "F") | [.command, .prompts[0].type] | join(" ")' \
    <(render_with dev dot_config/lazygit/config.yml.tmpl)
  [ "$output" = "git push --force-with-lease confirm" ]
}

@test "gitignore: new shared templates can be committed" {
  run git -C "$REPO_ROOT" check-ignore -q home/.chezmoitemplates/new.tmpl
  [ "$status" -eq 1 ]
}

@test "zsh: syntax highlighting is the last thing .zshrc loads" {
  local rendered
  rendered="$(render_with dev dot_zshrc.tmpl)"
  [[ "$rendered" != *"zsh-syntax-highlighting.zsh"* ]]
  # shellcheck disable=SC2016 # the literal text in .zshrc
  [ "$(printf '%s\n' "$rendered" | grep -n 'source "$_fsh_plugin"' | cut -d: -f1)" -gt \
    "$(printf '%s\n' "$rendered" | grep -n '.zshrc.local"$' | tail -1 | cut -d: -f1)" ]
}
