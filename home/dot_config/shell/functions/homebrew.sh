#!/usr/bin/env bash
# homebrew - Get a Machine ready for `brew bundle`, or say why it cannot be.
#
#   . homebrew.sh
#   homebrew_prepare || exit 0    # non-zero: warned, skip Homebrew
#
# Homebrew serves a Machine only on a Homebrew platform (GLOSSARY.md, docs/adr/0004):
# Tier 1 or 2 of https://docs.brew.sh/Support-Tiers, or WSL 2. Anything else warns
# and skips rather than failing Apply. A failed install is a real failure and exits.
# Needs log.sh. Bash only: Apply and the dev container build source this.

# The official installer at a fixed commit, bumped by hand like mise in
# tools/bootstrap.sh. This pins the bootstrap only: Homebrew then updates itself.
HOMEBREW_INSTALL_COMMIT="d6a2423c5973e04b45a5f17dc1948f6c9e5e651a"
HOMEBREW_INSTALL_SHA256="5f333bbe53bc490e51e7ccb1df8779b3dd6ee73a1a7379efda216edb08ccb148"

# Print the path of an installed brew.
homebrew_find() {
    local candidate
    # shellcheck disable=SC2086 # the override is a space-separated list
    for candidate in "$(command -v brew || true)" \
        ${DOTFILES_HOMEBREW_LOCATIONS:-/opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew "$HOME/.linuxbrew/bin/brew"}; do
        if [[ -n "$candidate" && -x "$candidate" ]]; then
            echo "$candidate"
            return 0
        fi
    done
    return 1
}

# True inside a container, the one place Homebrew accepts root.
homebrew_in_container() {
    local marker
    # shellcheck disable=SC2086 # the override is a space-separated list
    for marker in ${DOTFILES_CONTAINER_MARKERS:-/.dockerenv /run/.containerenv}; do
        [[ -f "$marker" ]] && return 0
    done
    return 1
}

# Print why Homebrew cannot serve this platform; print nothing if it can.
homebrew_platform_problem() {
    local arch major
    arch="$(uname -m)"
    case "$(uname -s)" in
    Darwin)
        if [[ "$arch" != arm64 ]]; then
            echo "Intel macOS is Homebrew Tier 3"
            return 0
        fi
        major="$(sw_vers -productVersion)"
        major="${major%%.*}"
        if ((major < 15)); then
            echo "macOS $major is Homebrew Tier 3 (it needs macOS 15 or newer)"
        fi
        ;;
    Linux)
        case "$arch" in
        x86_64 | aarch64 | arm64) ;;
        *)
            echo "Linux on $arch is not a Homebrew platform (no bottles)"
            return 0
            ;;
        esac
        # WSL 2 kernels say "microsoft-standard"; WSL 1 says "Microsoft".
        if [[ "$(uname -r)" == *-Microsoft ]]; then
            echo "WSL 1 is Homebrew Tier 3 (WSL 2 is supported)"
        elif ! getconf GNU_LIBC_VERSION >/dev/null 2>&1; then
            echo "Homebrew needs glibc, and this Linux does not use it"
        fi
        ;;
    *) echo "$(uname -s) is not a Homebrew platform" ;;
    esac
}

# True if this user can create Homebrew's prefix.
homebrew_can_install() {
    local prefix=/opt/homebrew
    [[ "$(uname -s)" == Darwin ]] || prefix=/home/linuxbrew/.linuxbrew
    [[ "$(id -u)" == 0 || -w "$prefix" ]] && return 0
    command -v sudo >/dev/null 2>&1 || return 1
    sudo -n true 2>/dev/null && return 0
    # A person at a terminal can answer the password prompt once, up front; the
    # installer itself runs NONINTERACTIVE and cannot ask.
    [[ -t 0 ]] && sudo -v
}

homebrew_sha256() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    else
        shasum -a 256 "$1" | awk '{print $1}'
    fi
}

# Download the pinned installer, verify it and run it. Exits on any failure.
homebrew_install() {
    local installer got status=0
    installer="$(mktemp)"
    log_state "Installing Homebrew"
    curl -fsSL "https://raw.githubusercontent.com/Homebrew/install/${HOMEBREW_INSTALL_COMMIT}/install.sh" \
        -o "$installer" || status=$?
    if ((status == 0)); then
        got="$(homebrew_sha256 "$installer")"
        if [[ "$got" != "$HOMEBREW_INSTALL_SHA256" ]]; then
            log_error "Homebrew installer checksum mismatch: expected $HOMEBREW_INSTALL_SHA256, got $got"
            status=1
        else
            NONINTERACTIVE=1 /bin/bash "$installer" || status=$?
        fi
    fi
    rm -f "$installer"
    ((status == 0)) || exit "$status"
}

# Make `brew` usable in this shell. Returns non-zero, after a warning, when this
# Machine should skip Homebrew.
homebrew_prepare() {
    local problem brew_bin
    problem="$(homebrew_platform_problem)"
    if [[ -n "$problem" ]]; then
        log_warn "Skipping Homebrew: $problem"
        return 1
    fi
    if [[ "$(id -u)" == 0 ]] && ! homebrew_in_container; then
        log_warn "Skipping Homebrew: it refuses to run as root outside a container"
        return 1
    fi
    if ! brew_bin="$(homebrew_find)"; then
        if ! homebrew_can_install; then
            log_warn "Skipping Homebrew: installing it needs sudo to create its prefix"
            return 1
        fi
        homebrew_install
        brew_bin="$(homebrew_find)" || {
            log_error "Homebrew installed, but brew was not found"
            exit 1
        }
    fi
    eval "$("$brew_bin" shellenv)"
}
