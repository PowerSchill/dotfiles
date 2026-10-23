# Extract various archive formats
function extract() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: extract <archive_file(s)>"
        return 1
    fi

    for file in "$@"; do
        if [[ -f "$file" ]]; then
            case "$file" in
                *.tar.bz2|*.tbz2) tar xjf "$file" ;;
                *.tar.gz|*.tgz)   tar xzf "$file" ;;
                *.tar.xz|*.txz)   tar xJf "$file" ;;
                *.tar.zst)        tar --zstd -xf "$file" ;;
                *.tar)            tar xf "$file" ;;
                *.bz2)            bunzip2 "$file" ;;
                *.gz)             gunzip "$file" ;;
                *.xz)             unxz "$file" ;;
                *.zst)            unzstd "$file" ;;
                *.rar)            unrar x "$file" ;;
                *.zip)            unzip "$file" ;;
                *.Z)              uncompress "$file" ;;
                *.7z)             7z x "$file" ;;
                *)
                    echo "Error: '$file' - unknown archive format"
                    return 1
                    ;;
            esac
            echo "Successfully extracted: $file"
        else
            echo "Error: '$file' is not a valid file"
            return 1
        fi
    done
}

# Create a tar.gz archive from files or directories
function maketar() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: maketar <file_or_directory>"
        return 1
    fi

    local target="${1%%/}"
    if [[ ! -e "$target" ]]; then
        echo "Error: '$target' does not exist"
        return 1
    fi

    tar czf "${target}.tar.gz" "$target" && echo "Created: ${target}.tar.gz"
}

# Create a ZIP archive of files or directories
function makezip() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: makezip <file_or_directory>"
        return 1
    fi

    local target="${1%%/}"
    if [[ ! -e "$target" ]]; then
        echo "Error: '$target' does not exist"
        return 1
    fi

    zip -r "${target}.zip" "$target" && echo "Created: ${target}.zip"
}

# List contents of an archive without extracting
function lsarchive() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: lsarchive <archive_file>"
        return 1
    fi

    if [[ ! -f "$1" ]]; then
        echo "Error: '$1' is not a valid file"
        return 1
    fi

    case "$1" in
        *.tar.bz2|*.tbz2) tar tjf "$1" ;;
        *.tar.gz|*.tgz)   tar tzf "$1" ;;
        *.tar.xz|*.txz)   tar tJf "$1" ;;
        *.tar.zst)        tar --zstd -tf "$1" ;;
        *.tar)            tar tf "$1" ;;
        *.rar)            unrar l "$1" ;;
        *.zip)            unzip -l "$1" ;;
        *.7z)             7z l "$1" ;;
        *)
            echo "Error: '$1' - unknown archive format"
            return 1
            ;;
    esac
}
