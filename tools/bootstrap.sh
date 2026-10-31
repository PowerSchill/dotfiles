#!/usr/bin/env bash
# Install the repository Toolchain on a clean machine, non-interactively.
# Safe to re-run: every step is a no-op once done.
#
#   tools/bootstrap.sh                       Profile detected from the environment
#   DOTFILES_PROFILE=minimal tools/bootstrap.sh
#
# Steps:
#   1. ensure mise >= MISE_VERSION is available (installs the pinned, checksum-verified
#      release into ~/.local/bin when it is not)
#   2. trust this repo's mise config without prompting
#   3. `mise run install` (records the Profile, installs tools, installs git hooks)
#
# This bootstraps the Toolchain for working on the repo. Machines get their
# dotfiles through `chezmoi init --apply` as described in README.MD.
set -euo pipefail

MISE_VERSION="2026.10.25"
# sha256 of mise-v${MISE_VERSION}-<platform>.tar.gz, from the release's SHASUMS256.txt.
mise_sha256() {
    case "$1" in
    linux-x64) echo 199966edaad1b208eb4c72955f1722dafb8fa799f575db720dea05aaa8216546 ;;
    linux-arm64) echo a7d1e2add53441ff76e7e971e7a3fb15c117741836ce51c026f5fb7eebe7dbcf ;;
    macos-x64) echo 2b31afc1ef77c46bf9cb0837dba9366ad744f452343a0f8b00d3df1eef892f84 ;;
    macos-arm64) echo 774236e3247e48d78078c0bce79e5327d4e4479f1a94c8487827f178197ee39b ;;
    *) return 1 ;;
    esac
}

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
install_dir="${MISE_INSTALL_DIR:-$HOME/.local/bin}"

log() { printf 'bootstrap: %s\n' "$*"; }
die() {
    printf 'bootstrap: error: %s\n' "$*" >&2
    exit 1
}

require() {
    command -v "$1" >/dev/null 2>&1 || die "'$1' is required but not installed. $2"
}

platform() {
    local os arch
    case "$(uname -s)" in
    Linux) os=linux ;;
    Darwin) os=macos ;;
    *) die "unsupported OS '$(uname -s)'. Use Linux, macOS, or WSL (see docs/adr/0002)." ;;
    esac
    case "$(uname -m)" in
    x86_64 | amd64) arch=x64 ;;
    aarch64 | arm64) arch=arm64 ;;
    *) die "unsupported CPU '$(uname -m)'." ;;
    esac
    echo "$os-$arch"
}

# True when the given mise binary is at least MISE_VERSION (CalVer sorts with -V).
mise_ok() {
    local have
    have="$("$1" --version 2>/dev/null | awk '{print $1}')" || return 1
    [[ -n "$have" ]] || return 1
    [[ "$(printf '%s\n%s\n' "$MISE_VERSION" "$have" | sort -V | head -n1)" == "$MISE_VERSION" ]]
}

sha256() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | awk '{print $1}'
    else
        die "'sha256sum' or 'shasum' is required to verify the mise download."
    fi
}

install_mise() {
    local plat want tmp url
    plat="$(platform)"
    want="$(mise_sha256 "$plat")" || die "no pinned checksum for platform '$plat'."
    require curl "Install curl with your package manager (apt-get install curl, dnf install curl)."
    require tar "Install tar with your package manager."

    url="https://github.com/jdx/mise/releases/download/v${MISE_VERSION}/mise-v${MISE_VERSION}-${plat}.tar.gz"
    tmp="$(mktemp -d)"
    # shellcheck disable=SC2064 # expand $tmp now
    trap "rm -rf '$tmp'" EXIT

    log "installing mise $MISE_VERSION ($plat) into $install_dir"
    curl -fsSL --retry 3 -o "$tmp/mise.tar.gz" "$url" || die "download failed: $url"
    [[ "$(sha256 "$tmp/mise.tar.gz")" == "$want" ]] || die "checksum mismatch for $url"
    tar -xzf "$tmp/mise.tar.gz" -C "$tmp"
    mkdir -p "$install_dir"
    install -m 0755 "$tmp/mise/bin/mise" "$install_dir/mise"
}

ensure_mise() {
    local candidate
    for candidate in "$(command -v mise 2>/dev/null || true)" "$install_dir/mise"; do
        if [[ -n "$candidate" && -x "$candidate" ]] && mise_ok "$candidate"; then
            MISE="$candidate"
            log "using $("$MISE" --version | awk '{print $1}') at $MISE"
            return
        fi
    done
    install_mise
    MISE="$install_dir/mise"
    mise_ok "$MISE" || die "installed mise does not report version $MISE_VERSION."
}

main() {
    require git "Install git with your package manager."
    ensure_mise

    # Non-interactive from here on: trust this checkout's config and answer yes to prompts.
    export MISE_YES=1
    export MISE_TRUSTED_CONFIG_PATHS="$root${MISE_TRUSTED_CONFIG_PATHS:+:$MISE_TRUSTED_CONFIG_PATHS}"
    cd "$root"
    # Tasks call `mise` by name, so make sure the one we chose is first on PATH.
    PATH="$(dirname "$MISE"):$PATH"
    export PATH
    local config
    for config in mise.toml mise.full.toml; do
        "$MISE" trust --quiet "$root/$config" </dev/null
    done

    # Record the Profile before mise loads config, so `install` sees the right tool set.
    log "profile: $(tools/bin/dotfiles-profile --write)"
    env -u MISE_ENV "$MISE" run install </dev/null

    if [[ "$MISE" == "$install_dir/mise" ]] && ! command -v mise >/dev/null 2>&1; then
        log "add $install_dir to PATH to use mise directly"
    fi
    log "done. Run 'mise tasks' to list the available chores."
}

main "$@"
