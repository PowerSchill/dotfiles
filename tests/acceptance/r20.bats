#!/usr/bin/env bats
# R20: Linux Machines get their Packages from Homebrew, using the same Brewfile as
# macOS, after only the native prerequisites.
# Test: in fresh containers as an unprivileged user, the real install scripts install
# the native list, then Homebrew from its pinned commit, then a small Brewfile. Casks
# and `mas` that cannot run on Linux are skipped, and a Machine that cannot install
# Homebrew warns without failing. The full Package list is left out: it takes too long
# and would fail this test on every upstream change.

# Commands in single quotes are expanded inside the container, not here.
# shellcheck disable=SC2016

load helpers

teardown() { container_stop; }

# Replace packages.homebrew with a small list, and render the install scripts for
# this container with the given Roles into ~/scripts.
prepare_scripts() {
  run container_exec 'tools/bootstrap.sh >/dev/null 2>&1 &&
    cat >/tmp/small.yaml <<YAML
brews:
  base:
    - name: hello
    - name: mac-only
      platforms: [macos]
casks:
  base:
    - name: alfred
mas:
  base:
    - name: Xcode
      options: { id: 497799835 }
YAML
    mise x -- yq -i ".packages.homebrew = load(\"/tmp/small.yaml\")" home/.chezmoidata/packages.yaml &&
    cfg="$(mise x -- tools/bin/dotfiles-role-config dev /tmp/cfg)" &&
    id="$(. /etc/os-release && echo "$ID")" &&
    mise x -- yq -i ".data.osid = \"linux-$id\"" "$cfg" &&
    mkdir -p ~/scripts &&
    for s in linux/run_onchange_before_10_install-packages packages/run_onchange_before_install-packages; do
      mise x -- chezmoi --source "$PWD" --config "$cfg" --persistent-state /tmp/cfg/state.boltdb --no-tty \
        execute-template <"home/.chezmoiscripts/$s.sh.tmpl" >~/scripts/"$(dirname "$s")".sh || exit 1
    done'
  echo "$output"
  [ "$status" -eq 0 ]
}

give_sudo() {
  container_root 'if command -v apt-get >/dev/null; then
      apt-get install -y -qq --no-install-recommends sudo >/dev/null
    else
      dnf install -y -q sudo >/dev/null
    fi &&
    echo "'"$CONTAINER_USER"' ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/dev'
}

installs_through_homebrew() {
  ACCEPTANCE_IMAGE="$1" container_start
  give_sudo
  prepare_scripts
  run container_exec 'bash ~/scripts/linux.sh && bash ~/scripts/packages.sh'
  echo "$output"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Installing Homebrew"* ]]
  [[ "$output" == *"Skipping cask alfred (requires macOS)"* ]]
  [[ "$output" == *"Skipping mas Xcode (requires macOS)"* ]]

  # The Brewfile is the only source: hello came from it, and mac-only was filtered out.
  run container_exec 'grep -c "mac-only" ~/.Brewfile; /home/linuxbrew/.linuxbrew/bin/hello'
  echo "$output"
  [ "${lines[0]}" = 0 ]
  [ "${lines[1]}" = "Hello, world!" ]

  # A shell sourcing homebrew-env finds Homebrew's copy first.
  run container_exec '. home/dot_config/shell/homebrew-env.sh; command -v hello; echo "$HOMEBREW_BUNDLE_FILE_GLOBAL"; brew bundle check --global'
  echo "$output"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = /home/linuxbrew/.linuxbrew/bin/hello ]
  [ "${lines[1]}" = "/home/$CONTAINER_USER/.Brewfile" ]
}

@test "R20: Ubuntu installs native prerequisites, then Homebrew, then the Brewfile" {
  installs_through_homebrew ubuntu:24.04
}

@test "R20: Fedora installs native prerequisites, then Homebrew, then the Brewfile" {
  installs_through_homebrew fedora:43
}

@test "R20: without sudo, Homebrew is skipped with a warning and Apply carries on" {
  container_start
  prepare_scripts
  run container_exec 'bash ~/scripts/packages.sh; echo "exit=$?"'
  echo "$output"
  [[ "$output" == *"Skipping Homebrew: installing it needs sudo"* ]]
  [[ "$output" == *"exit=0"* ]]
  run container_exec 'test ! -e /home/linuxbrew'
  [ "$status" -eq 0 ]
}
