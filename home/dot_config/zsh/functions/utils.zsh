#!/usr/bin/env zsh

# Make your directories and files access rights sane
# Sets owner: rwX, group: rX, others: none
function sanitize() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: sanitize <file_or_directory>..."
        return 1
    fi

    for item in "$@"; do
        if [[ ! -e "$item" ]]; then
            echo "Error: '$item' does not exist"
            return 1
        fi
    done

    chmod -R u=rwX,g=rX,o= "$@" && echo "✓ Sanitized permissions for: $*"
}

# Swap 2 filenames around
function swap() {
    if [[ $# -ne 2 ]]; then
        echo "Usage: swap <file1> <file2>"
        return 1
    fi

    if [[ ! -e "$1" ]]; then
        echo "Error: '$1' does not exist"
        return 1
    fi

    if [[ ! -e "$2" ]]; then
        echo "Error: '$2' does not exist"
        return 1
    fi

    local tmpfile
    tmpfile=$(mktemp) || return 1

    mv "$1" "$tmpfile" && \
    mv "$2" "$1" && \
    mv "$tmpfile" "$2" && \
    echo "✓ Swapped: '$1' ↔ '$2'"
}

# Create a timestamped backup of a file or directory
function backup() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: backup <file_or_directory>..."
        return 1
    fi

    for item in "$@"; do
        if [[ ! -e "$item" ]]; then
            echo "Error: '$item' does not exist"
            return 1
        fi

        local timestamp
        timestamp=$(date +%Y%m%d_%H%M%S)
        local backup_name="${item}.backup_${timestamp}"

        if cp -r "$item" "$backup_name"; then
            echo "✓ Created backup: $backup_name"
        else
            echo "✗ Failed to backup: $item"
            return 1
        fi
    done
}

# Encode text to base64
function encode64() {
    if [[ -t 0 ]] && [[ $# -eq 0 ]]; then
        echo "Usage: encode64 <text> OR echo 'text' | encode64"
        return 1
    fi

    if [[ $# -gt 0 ]]; then
        echo -n "$*" | base64
    else
        base64
    fi
}

# Decode base64 text
function decode64() {
    if [[ -t 0 ]] && [[ $# -eq 0 ]]; then
        echo "Usage: decode64 <base64_text> OR echo 'base64' | decode64"
        return 1
    fi

    if [[ $# -gt 0 ]]; then
        echo -n "$*" | base64 -d
    else
        base64 -d
    fi
}

# Convert text to lowercase
function lowercase() {
    if [[ -t 0 ]] && [[ $# -eq 0 ]]; then
        echo "Usage: lowercase <text> OR echo 'TEXT' | lowercase"
        return 1
    fi

    if [[ $# -gt 0 ]]; then
        echo "$*" | tr '[:upper:]' '[:lower:]'
    else
        tr '[:upper:]' '[:lower:]'
    fi
}

# Convert text to uppercase
function uppercase() {
    if [[ -t 0 ]] && [[ $# -eq 0 ]]; then
        echo "Usage: uppercase <text> OR echo 'text' | uppercase"
        return 1
    fi

    if [[ $# -gt 0 ]]; then
        echo "$*" | tr '[:lower:]' '[:upper:]'
    else
        tr '[:lower:]' '[:upper:]'
    fi
}

# Quick calculator using bc
function calc() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: calc <expression>"
        echo "Example: calc '2 + 2'"
        echo "         calc 'sqrt(16)'"
        return 1
    fi

    if ! command -v bc &>/dev/null; then
        echo "Error: bc is required but not installed"
        return 1
    fi

    echo "$*" | bc -l
}

# Get weather information for a location
function weather() {
    local location="${*:-}"

    if ! command -v curl &>/dev/null; then
        echo "Error: curl is required but not installed"
        return 1
    fi

    if [[ -n "$location" ]]; then
        curl -s "wttr.in/${location// /+}?format=3"
    else
        curl -s "wttr.in/?format=3"
    fi
    echo
}

# Get detailed weather forecast
function forecast() {
    local location="${*:-}"

    if ! command -v curl &>/dev/null; then
        echo "Error: curl is required but not installed"
        return 1
    fi

    if [[ -n "$location" ]]; then
        curl -s "wttr.in/${location// /+}"
    else
        curl -s "wttr.in/"
    fi
}

# Generate a random string
function randstr() {
    local length="${1:-32}"

    if ! [[ "$length" =~ ^[0-9]+$ ]]; then
        echo "Usage: randstr [length]"
        echo "Length must be a positive integer (default: 32)"
        return 1
    fi

    if command -v openssl &>/dev/null; then
        openssl rand -base64 "$((length * 3 / 4))" | tr -d '\n=' | cut -c1-"$length"
    else
        cat /dev/urandom | LC_ALL=C tr -dc 'a-zA-Z0-9' | head -c "$length"
    fi
    echo
}

# Get file size in human readable format
function fsize() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: fsize <file>..."
        return 1
    fi

    for file in "$@"; do
        if [[ ! -e "$file" ]]; then
            echo "Error: '$file' does not exist"
            return 1
        fi

        if command -v du &>/dev/null; then
            du -sh "$file"
        else
            ls -lh "$file" | awk '{print $5, $9}'
        fi
    done
}

# Create an alias for a command with confirmation
function realias() {
    if [[ $# -lt 2 ]]; then
        echo "Usage: realias <alias_name> <command>"
        return 1
    fi

    local alias_name="$1"
    shift
    local alias_cmd="$*"

    alias "$alias_name"="$alias_cmd"
    echo "✓ Created alias: $alias_name='$alias_cmd'"
}

# Find and replace text in files
function findreplace() {
    if [[ $# -lt 2 ]]; then
        echo "Usage: findreplace <search_text> <replace_text> [file_pattern]"
        echo "Example: findreplace 'old' 'new' '*.txt'"
        return 1
    fi

    local search="$1"
    local replace="$2"
    local pattern="${3:-*}"

    if ! command -v sed &>/dev/null; then
        echo "Error: sed is required but not installed"
        return 1
    fi

    echo "Searching for: '$search' in files matching: $pattern"
    echo -n "Replace with: '$replace'? [y/N] "
    read -r response

    if [[ "$response" =~ ^[Yy]$ ]]; then
        find . -type f -name "$pattern" -exec sed -i.bak "s/$search/$replace/g" {} \;
        echo "✓ Replacement complete. Backup files created with .bak extension"
    else
        echo "Cancelled"
        return 1
    fi

