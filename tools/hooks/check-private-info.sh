#!/usr/bin/env bash
################################################################################
# Block private information from entering this public dotfiles repo.
#
# Complements gitleaks (which finds generic secrets) with checks specific to
# this repo:
#   - files that are keys, credentials, or secret stores by name
#   - home-directory paths for any user other than the allowed ones
#   - email addresses outside the allowed domains
#   - patterns from a local, untracked denylist (employer names, work
#     usernames, internal hostnames...) so they are never published here
#
# Scans only *added* lines: staged changes at pre-commit, or the pushed range
# at pre-push (PRE_COMMIT_FROM_REF / PRE_COMMIT_TO_REF, set by pre-commit).
#
# A single line can be exempted by putting `allow-private-info` on it.
################################################################################
set -euo pipefail

DENYLIST="${DOTFILES_PRIVATE_PATTERNS:-${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/private-patterns}"

# Usernames that may appear in /Users/<name> or /home/<name> paths.
ALLOWED_USERS='^(powerschill|user|username|runner|Shared|linuxbrew)$'

# Email domains that may appear in tracked files.
ALLOWED_EMAIL='@(cmschill\.net|users\.noreply\.github\.com|noreply\.github\.com|example\.(com|org|net)|y\.com)$'

# Paths that must never be committed. chezmoi's encrypted_ prefix is exempt.
FORBIDDEN_PATH='(^|/)(private_)*id_(rsa|dsa|ecdsa|ed25519)(\.tmpl)?$'
FORBIDDEN_PATH+='|(^|/)(private_)*(dot_|\.)(netrc|pgpass|git-credentials|env|envrc)(\.tmpl)?$'
FORBIDDEN_PATH+='|\.(pem|p12|pfx|key|kdbx|keychain|ovpn|tfstate|tfvars)(\.tmpl)?$'
FORBIDDEN_PATH+='|(^|/)(private_)*(dot_|\.)(aws|kube|op)/'
FORBIDDEN_PATH+='|(^|/)(private_)*(dot_|\.)docker/(private_)*config\.json'

if [[ -n "${PRE_COMMIT_FROM_REF:-}" && -n "${PRE_COMMIT_TO_REF:-}" ]]; then
    if [[ "$PRE_COMMIT_FROM_REF" =~ ^0+$ ]]; then
        range=("$PRE_COMMIT_TO_REF" --not --remotes)
    else
        range=("$PRE_COMMIT_FROM_REF..$PRE_COMMIT_TO_REF")
    fi
    files=$(git log --format= --name-only --diff-filter=AR "${range[@]}" | sort -u)
    diff=$(git log -p --format= --unified=0 --no-color "${range[@]}")
else
    files=$(git diff --cached --name-only --diff-filter=AR)
    diff=$(git diff --cached --unified=0 --no-color)
fi

failed=0
report() {
    printf '  %s\n' "$@" >&2
    failed=1
}

# --- forbidden file names -----------------------------------------------------
while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    [[ "$(basename "$f")" == encrypted_* ]] && continue
    if [[ "$f" =~ $FORBIDDEN_PATH ]]; then
        report "forbidden file: $f (keys/credentials belong in 1Password or encrypted_ files)"
    fi
done <<<"$files"

# --- added lines, tagged with their file -------------------------------------
# Emits "file<TAB>line" for every added line in the diff.
added=$(awk '
    /^\+\+\+ / { file = substr($0, 7); next }
    /^\+/      { print file "\t" substr($0, 2) }
' <<<"$diff" | grep -v 'allow-private-info' || true)

[[ -z "$added" ]] && exit $failed

# --- home directory paths -----------------------------------------------------
while IFS=$'\t' read -r f user; do
    if ! [[ "$user" =~ $ALLOWED_USERS ]]; then
        report "$f: home path for user '$user'"
    fi
done < <(perl -ne '
    my ($f, $l) = split /\t/, $_, 2;
    print "$f\t$2\n" while $l =~ m{(?<![\w\}.])(?:/|\\/|\\\\)(Users|home)(?:/|\\/|\\\\)([A-Za-z0-9_-][A-Za-z0-9._-]*)}g;
' <<<"$added" | sort -u)

# --- email addresses ----------------------------------------------------------
while IFS=$'\t' read -r f email; do
    if ! [[ "$email" =~ $ALLOWED_EMAIL ]]; then
        report "$f: email address '$email'"
    fi
done < <(perl -ne '
    my ($f, $l) = split /\t/, $_, 2;
    print "$f\t$1\n" while $l =~ /([A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,})/g;
' <<<"$added" | grep -v $'\tgit@' | sort -u)

# --- local denylist -----------------------------------------------------------
if [[ -r "$DENYLIST" ]]; then
    while IFS= read -r pattern; do
        [[ -z "$pattern" || "$pattern" == \#* ]] && continue
        while IFS= read -r hit; do
            report "${hit%%$'\t'*}: matches private pattern '$pattern'"
        done < <(PAT="$pattern" perl -ne 'print if /$ENV{PAT}/i' <<<"$added" | sort -u -t$'\t' -k1,1)
    done <"$DENYLIST"
else
    echo "check-private-info: no denylist at $DENYLIST (employer/host patterns not checked)" >&2
fi

if ((failed)); then
    echo "check-private-info: private information found (see above)." >&2
    echo "  Remove it, move it to ~/.zshrc.local or 1Password, or mark the line with allow-private-info." >&2
fi
exit $failed
