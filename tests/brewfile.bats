#!/usr/bin/env bats
# The Brewfile renderer and check:packages. Rendered from fixtures, never this
# Machine's own config. brew is only needed by the tests that say so.

# Fixtures hold literal ${HOMEBREW_PREFIX}: it is for Homebrew, never this shell.
# shellcheck disable=SC2016

load helpers

# Render brewfile.tmpl with $BATS_TEST_TMPDIR/homebrew.yaml as packages.homebrew.
#   brewfile <macos|linux|wsl> [roles]
brewfile() {
  local platform="$1" roles="${2:-dev}" cfg os=linux wsl=false
  [ "$platform" != macos ] || os=darwin
  [ "$platform" != wsl ] || wsl=true
  cfg="$(role_config "$roles")"
  chezmoi --source "$REPO_ROOT" --config "$cfg" \
    --persistent-state "$(dirname "$cfg")/state.boltdb" \
    --destination "$BATS_TEST_TMPDIR/fakehome" --no-tty execute-template <<TMPL
{{ \$d := deepCopy . }}
{{- \$_ := set \$d.packages "homebrew" (include "$BATS_TEST_TMPDIR/homebrew.yaml" | fromYaml) -}}
{{- \$_ := set \$d.chezmoi "os" "$os" -}}
{{- \$_ := set \$d "wsl" $wsl -}}
{{- template "brewfile.tmpl" \$d -}}
TMPL
}

fixture() { cat >"$BATS_TEST_TMPDIR/homebrew.yaml"; }

# Write a packages.yaml with this YAML as packages.homebrew; run check:packages on it.
check_packages() {
  local dir="$BATS_TEST_TMPDIR/check"
  mkdir -p "$dir"
  {
    echo 'packages:'
    echo '  homebrew:'
    sed 's/^/    /'
    printf '%s\n' "${NATIVE_YAML:-}"
  } >"$dir/packages.yaml"
  run "$REPO_ROOT/tools/checks/packages.sh" "$dir/packages.yaml"
}

@test "brewfile: formula options are written as Ruby" {
  fixture <<'YAML'
brews:
  base:
    - name: denji/nginx/nginx-full
      options:
        args: [with-rmtp, with-other]
        link: ":overwrite"
        postinstall: "${HOMEBREW_PREFIX}/bin/x"
        restart_service: ":always"
        trusted: true
        version_file: .nginx-version
    - name: mysql@5.6
      options: { conflicts_with: [mysql], link: true, restart_service: ":changed" }
YAML
  run brewfile macos
  [ "$status" -eq 0 ]
  [[ "$output" == *'brew "denji/nginx/nginx-full", args: ["with-rmtp", "with-other"], link: :overwrite, postinstall: "${HOMEBREW_PREFIX}/bin/x", restart_service: :always, trusted: true, version_file: ".nginx-version"'* ]]
  [[ "$output" == *'brew "mysql@5.6", conflicts_with: ["mysql"], link: true, restart_service: :changed'* ]]
}

@test "brewfile: a tap's url is positional and its trust is a nested map" {
  fixture <<'YAML'
taps:
  base:
    - name: user/repo
      options:
        url: https://example.com/homebrew-repo.git
        trusted: { formula: one, casks: [two, three] }
YAML
  run brewfile macos
  [[ "$output" == *'tap "user/repo", "https://example.com/homebrew-repo.git", trusted: { casks: ["two", "three"], formula: "one" }'* ]]
}

@test "brewfile: cask options, cask_args and ENV" {
  fixture <<'YAML'
env: { SOME_VAR: a value }
caskArgs: { appdir: ~/Applications, require_sha: true }
casks:
  base:
    - name: firefox
      options: { args: { appdir: ~/my-apps, language: en }, greedy: true, postinstall: run }
YAML
  run brewfile macos
  [[ "$output" == *'ENV["SOME_VAR"] = "a value"'* ]]
  [[ "$output" == *'cask_args appdir: "~/Applications", require_sha: true'* ]]
  [[ "$output" == *'cask "firefox", args: { appdir: "~/my-apps", language: "en" }, greedy: true, postinstall: "run"'* ]]
}

@test "brewfile: every other entry type and its options" {
  fixture <<'YAML'
mas: { base: [{ name: Refined GitHub, options: { id: 1519867270 } }] }
vscode: { base: [{ name: editorconfig.editorconfig }] }
go: { base: [{ name: github.com/charmbracelet/crush }] }
cargo: { base: [{ name: bat, options: { source: "https://github.com/sharkdp/bat" } }] }
uv: { base: [{ name: ruff, options: { source: "git+https://example.com/ruff.git", with: [extra] } }] }
npm: { base: [{ name: prettier }] }
krew: { base: [{ name: ctx }] }
flatpak: { base: [{ name: org.godotengine.Godot, options: { remote: flathub-beta, url: "https://dl.example/" } }] }
winget: { base: [{ name: Steam, options: { id: Valve.Steam, source: msstore } }] }
YAML
  run brewfile wsl
  [ "$status" -eq 0 ]
  [[ "$output" == *'mas "Refined GitHub", id: 1519867270'* ]]
  [[ "$output" == *'vscode "editorconfig.editorconfig"'* ]]
  [[ "$output" == *'go "github.com/charmbracelet/crush"'* ]]
  [[ "$output" == *'cargo "bat", source: "https://github.com/sharkdp/bat"'* ]]
  [[ "$output" == *'uv "ruff", source: "git+https://example.com/ruff.git", with: ["extra"]'* ]]
  [[ "$output" == *'npm "prettier"'* ]]
  [[ "$output" == *'krew "ctx"'* ]]
  [[ "$output" == *'flatpak "org.godotengine.Godot", remote: "flathub-beta", url: "https://dl.example/"'* ]]
  [[ "$output" == *'winget "Steam", id: "Valve.Steam", source: "msstore"'* ]]
}

@test "brewfile: when is written as a Ruby modifier" {
  fixture <<'YAML'
casks:
  base:
    - name: java
      when: unless system "/usr/libexec/java_home", "--failfast"
YAML
  run brewfile macos
  [[ "$output" == *'cask "java" unless system "/usr/libexec/java_home", "--failfast"'* ]]
}

@test "brewfile: Ruby string interpolation is escaped" {
  fixture <<'YAML'
brews: { base: [{ name: a, options: { postinstall: "echo #{danger}" } }] }
YAML
  run brewfile macos
  [[ "$output" == *'postinstall: "echo \#{danger}"'* ]]
}

@test "brewfile: every entry applies everywhere unless platforms narrows it" {
  fixture <<'YAML'
brews:
  base:
    - name: everywhere
    - name: mac-only
      platforms: [macos]
    - name: linux-only
      platforms: [linux]
    - name: wsl-only
      platforms: [wsl]
casks:
  base:
    - name: some-cask
YAML
  run brewfile macos
  [[ "$output" == *'brew "everywhere"'* && "$output" == *'brew "mac-only"'* && "$output" == *'cask "some-cask"'* ]]
  [[ "$output" != *'brew "linux-only"'* && "$output" != *'brew "wsl-only"'* ]]
  run brewfile linux
  [[ "$output" == *'brew "everywhere"'* && "$output" == *'brew "linux-only"'* && "$output" == *'cask "some-cask"'* ]]
  [[ "$output" != *'brew "mac-only"'* && "$output" != *'brew "wsl-only"'* ]]
  run brewfile wsl
  [[ "$output" == *'brew "everywhere"'* && "$output" == *'brew "linux-only"'* && "$output" == *'brew "wsl-only"'* ]]
  [[ "$output" != *'brew "mac-only"'* ]]
}

@test "brewfile: winget only reaches WSL and flatpak only reaches Linux by default" {
  fixture <<'YAML'
winget: { base: [{ name: Steam, options: { id: Valve.Steam } }] }
flatpak: { base: [{ name: org.example.App }] }
YAML
  run brewfile macos
  [[ "$output" != *'winget "'* && "$output" != *'flatpak "'* ]]
  run brewfile linux
  [[ "$output" != *'winget "'* && "$output" == *'flatpak "org.example.App"'* ]]
  run brewfile wsl
  [[ "$output" == *'winget "Steam"'* && "$output" == *'flatpak "org.example.App"'* ]]
}

@test "brewfile: Ephemeral machines skip excludeEphemeral entries" {
  fixture <<'YAML'
brews:
  base:
    - name: small
    - name: heavy
      excludeEphemeral: true
YAML
  run brewfile linux ephemeral
  [[ "$output" == *'brew "small"'* && "$output" != *'brew "heavy"'* ]]
  run brewfile linux dev
  [[ "$output" == *'brew "small"'* && "$output" == *'brew "heavy"'* ]]
}

@test "brewfile: only base and enabled Role buckets are included" {
  fixture <<'YAML'
brews:
  base: [{ name: in-base }]
  dev: [{ name: in-dev }]
  security: [{ name: in-security }]
YAML
  run brewfile macos dev
  [[ "$output" == *'brew "in-base"'* && "$output" == *'brew "in-dev"'* && "$output" != *'brew "in-security"'* ]]
}

@test "packages: the install script does not expand Brewfile values" {
  local cfg bin="$BATS_TEST_TMPDIR/bin" home="$BATS_TEST_TMPDIR/home" script="$BATS_TEST_TMPDIR/install.sh"
  mkdir -p "$bin" "$home"
  printf '#!/bin/sh\nexit 0\n' >"$bin/brew"
  chmod +x "$bin/brew"
  cfg="$(role_config dev)"
  chezmoi --source "$REPO_ROOT" --config "$cfg" --override-data '{"chezmoi":{"os":"darwin"}}' --no-tty \
    execute-template <"$SOURCE_DIR/.chezmoiscripts/packages/run_onchange_before_install-packages.sh.tmpl" >"$script"
  # Prove the heredoc is literal: a line a shell would expand comes through unchanged.
  sed -i.bak '/^BREWFILE$/i\
brew "x", postinstall: "${HOMEBREW_PREFIX}/bin/x"
' "$script"
  run env -u HOMEBREW_PREFIX HOME="$home" PATH="$bin:$PATH" bash "$script"
  [ "$status" -eq 0 ]
  grep -qF 'postinstall: "${HOMEBREW_PREFIX}/bin/x"' "$home/.Brewfile"
}

@test "check:packages: the repo's packages.yaml passes" {
  run "$REPO_ROOT/tools/checks/packages.sh"
  echo "$output"
  [ "$status" -eq 0 ]
}

@test "check:packages: files not named packages.yaml are ignored" {
  run "$REPO_ROOT/tools/checks/packages.sh" README.MD
  [ "$status" -eq 0 ]
}

@test "check:packages: every documented option is accepted" {
  NATIVE_YAML='  linux: { debian: { packages: { base: [flatpak] } } }' check_packages <<'YAML'
env: { A: b }
caskArgs: { appdir: x }
taps:
  base:
    - name: u/t
      options: { url: https://x/y.git, trusted: { formula: a, formulae: [b], cask: c, casks: [d], command: e, commands: [f] } }
brews:
  base:
    - name: u/t/a
      options: { args: [x], conflicts_with: [y], link: true, postinstall: z, restart_service: ":changed", trusted: true, version_file: f }
    - name: b
      options: { link: ":overwrite", restart_service: true }
casks:
  base:
    - name: u/t/c
      options: { args: { appdir: x }, greedy: true, postinstall: z, trusted: true }
mas: { base: [{ name: m, options: { id: 1 } }] }
winget: { base: [{ name: w, options: { id: i, source: msstore } }] }
vscode: { base: [{ name: v }] }
go: { base: [{ name: g }] }
cargo: { base: [{ name: c, options: { source: https://x } }] }
uv: { base: [{ name: u, options: { source: "git+https://x", with: [e] } }] }
npm: { base: [{ name: n }] }
krew: { base: [{ name: k }] }
flatpak: { base: [{ name: f, options: { remote: r, url: https://x } }] }
YAML
  echo "$output"
  [ "$status" -eq 0 ]
}

@test "check:packages: rejects an option the entry type does not have" {
  check_packages <<'YAML'
casks: { base: [{ name: a, options: { restart_service: true } }] }
YAML
  [ "$status" -ne 0 ]
  [[ "$output" == *"casks.base: a: unknown cask option 'restart_service'"* ]]
}

@test "check:packages: rejects a mistyped option value" {
  check_packages <<'YAML'
brews: { base: [{ name: a, options: { restart_service: ":sometimes" } }] }
YAML
  [ "$status" -ne 0 ]
  [[ "$output" == *"option 'restart_service' must be"* ]]
}

@test "check:packages: rejects unknown keys, platforms, buckets and sections" {
  check_packages <<'YAML'
brews:
  gaming: [{ name: a }]
  base:
    - { name: b, args: { appdir: x } }
    - { name: c, platforms: [freebsd] }
    - { name: d, when: "OS.mac?" }
rubygems: { base: [{ name: e }] }
YAML
  [ "$status" -ne 0 ]
  [[ "$output" == *"brews.gaming: unknown bucket"* ]]
  [[ "$output" == *"b: unknown key 'args'"* ]]
  [[ "$output" == *"c: unknown platform 'freebsd'"* ]]
  [[ "$output" == *"d: when must start with"* ]]
  [[ "$output" == *"unknown section 'rubygems'"* ]]
}

@test "check:packages: mas and winget entries need an id" {
  check_packages <<'YAML'
mas: { base: [{ name: a }] }
winget: { base: [{ name: b }] }
YAML
  [ "$status" -ne 0 ]
  [[ "$output" == *"a: a mas entry needs the 'id' option"* ]]
  [[ "$output" == *"b: a winget entry needs the 'id' option"* ]]
}

@test "check:packages: flatpak entries need flatpak in a native list" {
  check_packages <<'YAML'
flatpak: { base: [{ name: a }] }
YAML
  [ "$status" -ne 0 ]
  [[ "$output" == *"flatpak: entries need"* ]]
}

@test "check:apply: Homebrew parses the rendered Brewfile when it is installed" {
  local bin="$BATS_TEST_TMPDIR/stub"
  mkdir -p "$bin"
  cat >"$bin/brew" <<'STUB'
#!/bin/sh
echo "brew $*" >>"$BREW_LOG"
grep -q '^brew "bat"' "${3#--file=}"
STUB
  chmod +x "$bin/brew"
  BREW_LOG="$BATS_TEST_TMPDIR/brew.log" DOTFILES_BREW="$bin/brew" run "$REPO_ROOT/tools/checks/apply.sh" dev
  echo "$output"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Homebrew parsed the Brewfile"* ]]
  grep -q '^brew bundle list --file=' "$BATS_TEST_TMPDIR/brew.log"
}

@test "check:apply: a Brewfile Homebrew cannot parse fails the Check" {
  local bin="$BATS_TEST_TMPDIR/stub"
  mkdir -p "$bin"
  printf '#!/bin/sh\necho "Invalid Brewfile" >&2\nexit 1\n' >"$bin/brew"
  chmod +x "$bin/brew"
  DOTFILES_BREW="$bin/brew" run "$REPO_ROOT/tools/checks/apply.sh" dev
  [ "$status" -ne 0 ]
  [[ "$output" == *"Homebrew could not parse"* ]]
}

@test "check:packages: the repo's third-party taps declare only narrow trust" {
  run yq -r '.packages.homebrew.taps[][]? | select(.options.trusted == true) | .name' \
    "$SOURCE_DIR/.chezmoidata/packages.yaml"
  [ -z "$output" ]
}

@test "check:packages: whole-tap trust is rejected" {
  check_packages <<'YAML'
taps: { base: [{ name: u/t, options: { trusted: true } }] }
YAML
  [ "$status" -ne 0 ]
  [[ "$output" == *"option 'trusted' must be a map"* ]]
}

@test "check:packages: a third-party entry needs trust" {
  check_packages <<'YAML'
brews: { base: [{ name: u/t/f }] }
casks: { base: [{ name: u/t/c }] }
YAML
  [ "$status" -ne 0 ]
  [[ "$output" == *"u/t/f: a third-party entry needs"* ]]
  [[ "$output" == *"u/t/c: a third-party entry needs"* ]]
}

@test "check:packages: trust on the entry or in its tap's map both count" {
  check_packages <<'YAML'
taps: { base: [{ name: u/t, options: { trusted: { formula: f } } }] }
brews: { base: [{ name: u/t/f }, { name: u/t/g, options: { trusted: true } }] }
YAML
  echo "$output"
  [ "$status" -eq 0 ]
}

@test "check:packages: core entries need no trust, and homebrew/ names are not third-party" {
  check_packages <<'YAML'
brews: { base: [{ name: bat }, { name: homebrew/core/git }] }
YAML
  echo "$output"
  [ "$status" -eq 0 ]
}

@test "check:packages: trust on a bare name is rejected, Homebrew would ignore it" {
  check_packages <<'YAML'
brews: { base: [{ name: bat, options: { trusted: true } }] }
YAML
  [ "$status" -ne 0 ]
  [[ "$output" == *"trusted needs a fully-qualified name"* ]]
}

@test "check:packages: a tap nothing is trusted from is rejected" {
  check_packages <<'YAML'
taps: { base: [{ name: u/t }] }
YAML
  [ "$status" -ne 0 ]
  [[ "$output" == *"nothing from this tap is trusted"* ]]
}

# Render the native package script for a distro, as the given Role set.
#   native_script <osid> [roles] [idLike]
native_script() {
  local osid="$1" roles="${2:-dev}" like="${3:-}" cfg
  cfg="$(role_config "$roles")"
  yq -i ".data.osid = \"$osid\"" "$cfg"
  chezmoi --source "$REPO_ROOT" --config "$cfg" --persistent-state "$(dirname "$cfg")/state.boltdb" \
    --override-data "{\"chezmoi\":{\"osRelease\":{\"idLike\":\"$like\"}}}" \
    --destination "$BATS_TEST_TMPDIR/fakehome" --no-tty execute-template \
    <"$SOURCE_DIR/.chezmoiscripts/linux/run_onchange_before_10_install-packages.sh.tmpl"
}

@test "native: Debian and Ubuntu get Homebrew's prerequisites, and nothing from cargo" {
  run native_script linux-ubuntu
  [ "$status" -eq 0 ]
  [[ "$output" == *'"build-essential" "curl" "file" "git" "procps" "zsh"'* ]]
  [[ "$output" != *cargo* && "$output" != *'"bat"'* && "$output" != *wezterm* ]]
  bash -n <<<"$output"
}

@test "native: only the gui Role sets up the WezTerm apt repository" {
  run native_script linux-ubuntu gui
  [[ "$output" == *'apt-get install -y gnupg'* && "$output" == *'apt.fury.io/wez'* && "$output" == *'"wezterm-nightly"'* ]]
  bash -n <<<"$output"
}

@test "native: Fedora installs the development group before its packages" {
  run native_script linux-fedora
  [ "$status" -eq 0 ]
  [[ "$output" == *'dnf -y group install "development-tools"'* ]]
  [[ "$output" == *'"procps-ng"'* && "$output" != *'copr enable'* ]]
  bash -n <<<"$output"
}

@test "native: a gui Fedora Machine keeps its COPR terminals" {
  run native_script linux-fedora gui
  [[ "$output" == *'copr enable "scottames/ghostty"'* && "$output" != *lazygit* ]]
}

@test "native: RHEL, its derivatives and Arch have prerequisite lists" {
  run native_script linux-rhel
  [[ "$output" == *'dnf -y group install "Development Tools"'* ]]
  bash -n <<<"$output"
  run native_script linux-rocky dev "rhel centos fedora"
  [[ "$output" == *'dnf -y group install "Development Tools"'* ]]
  run native_script linux-arch
  [[ "$output" == *'pacman -S --needed --noconfirm "base-devel"'* ]]
  bash -n <<<"$output"
  run native_script linux-manjaro dev arch
  [[ "$output" == *'pacman -S'* ]]
}

@test "native: an unknown distro warns about what Homebrew needs" {
  run native_script linux-mystery
  [ "$status" -eq 0 ]
  [[ "$output" == *'No native package list for linux-mystery'* ]]
  bash -n <<<"$output"
}

@test "packages: the shared install script is ignored on Windows" {
  grep -q '^\.chezmoiscripts/packages/\*\*$' "$SOURCE_DIR/.chezmoiignore"
}

@test "packages: Ephemeral machines skip the heavy Packages" {
  local cfg rendered
  cfg="$(role_config ephemeral)"
  rendered="$(chezmoi --source "$REPO_ROOT" --config "$cfg" --no-tty execute-template '{{ template "brewfile.tmpl" . }}')"
  [[ "$rendered" == *'brew "bat"'* ]]
  [[ "$rendered" != *'brew "ffmpeg"'* && "$rendered" != *'brew "gcc"'* && "$rendered" != *'brew "mysql"'* ]]
  [[ "$rendered" != *'cask "postman"'* ]]
}
