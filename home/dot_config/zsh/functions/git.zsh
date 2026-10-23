#!/usr/bin/env zsh

# Commit staged changes with a Claude-generated message
# Usage: gcm [-y] [extra git commit args...]
# Note: the staged diff is sent to Claude; don't use on diffs containing secrets or customer data.
function gcm() {
    local yes=0
    [[ "$1" == "-y" ]] && { yes=1; shift; }

    if git diff --cached --quiet; then
        echo "Error: nothing staged"
        return 1
    fi

    local msg
    msg=$(
        {
            git diff --cached --stat
            git diff --cached
        } | head -c 100000 | claude -p --model haiku \
            "Write a Conventional Commits message for this staged diff (stdin). \
Subject <=72 chars, imperative mood, optional short body explaining why. \
Output ONLY the message, no code fences or commentary."
    ) || { echo "Error: claude failed"; return 1; }

    [[ -z "$msg" ]] && { echo "Error: empty message"; return 1; }

    if (( ! yes )); then
        printf '%s\n\n' "$msg"
        read -q "REPLY?Commit? [y/N] " || { echo; return 1; }
        echo
    fi

    git commit "$@" -m "$msg"
}
