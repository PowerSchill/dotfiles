# Sync chezmoi-managed theme with current macOS appearance.
#
# Updates only the `appearance` field in ~/.config/chezmoi/chezmoi.yaml,
# then runs `chezmoi apply`. This is now just the cheap path: roles are
# persisted via promptBoolOnce, so `chezmoi init` no longer resets them
# based on network-visible hostname state. See functions/role.zsh.
theme-sync() {
    local config="${XDG_CONFIG_HOME:-$HOME/.config}/chezmoi/chezmoi.yaml"
    local appearance="dark"

    if [[ "$(uname)" == "Darwin" ]]; then
        if [[ "$(defaults read -g AppleInterfaceStyle 2>/dev/null)" != "Dark" ]]; then
            appearance="light"
        fi
    fi

    if [[ ! -f "$config" ]]; then
        echo "theme-sync: $config not found; run 'chezmoi init' first" >&2
        return 1
    fi

    if ! command -v yq >/dev/null 2>&1; then
        echo "theme-sync: yq is required" >&2
        return 1
    fi

    yq -i ".data.appearance = \"$appearance\"" "$config"
    chezmoi apply && exec zsh
}
