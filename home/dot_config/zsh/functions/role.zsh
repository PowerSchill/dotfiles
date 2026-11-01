# Manage this machine's chezmoi roles.
#
# A role is an opt-in capability (see .chezmoi.yaml.tmpl). Enabled roles decide
# which package buckets from .chezmoidata/packages.yaml get installed and which
# configuration templates render.
#
# Role choices are saved in ~/.config/chezmoi/chezmoi.yaml by `chezmoi init`, so
# this drives init rather than editing that file directly. Going through init
# keeps one source of truth and re-renders everything derived from the roles.
#
# NOTE: chezmoi keys --promptBool on the *prompt string*, which .chezmoi.yaml.tmpl
# deliberately sets to the bare role name. A saved role wins over the flag unless
# DOTFILES_ROLE_CHANGE names it.
#
#   cmrole list            show which roles are enabled
#   cmrole add <name>      enable a role and re-apply
#   cmrole remove <name>   disable a role and re-apply
cmrole() {
    local config="${XDG_CONFIG_HOME:-$HOME/.config}/chezmoi/chezmoi.yaml"
    local action="$1" name="$2"
    local -a ROLE_NAMES
    ROLE_NAMES=(dev gui work personal security onepassword homelab)

    if ! command -v chezmoi >/dev/null 2>&1; then
        echo "cmrole: chezmoi is required" >&2
        return 1
    fi

    case "$action" in
        list|"")
            if [[ ! -f "$config" ]]; then
                echo "cmrole: $config not found; run 'chezmoi init' first" >&2
                return 1
            fi
            if ! command -v yq >/dev/null 2>&1; then
                echo "cmrole: yq is required" >&2
                return 1
            fi
            local r
            for r in "${ROLE_NAMES[@]}"; do
                if [[ "$(yq -r ".data.role.${r}" "$config")" == "true" ]]; then
                    printf '  \033[32m✓\033[0m %s\n' "$r"
                else
                    printf '    \033[90m%s\033[0m\n' "$r"
                fi
            done
            ;;
        add|remove)
            if [[ -z "$name" ]]; then
                echo "cmrole: $action requires a role name" >&2
                return 1
            fi
            if [[ ! " ${ROLE_NAMES[*]} " == *" $name "* ]]; then
                echo "cmrole: unknown role '$name'" >&2
                echo "cmrole: known roles: ${ROLE_NAMES[*]}" >&2
                return 1
            fi
            local value=true
            [[ "$action" == "remove" ]] && value=false

            echo "cmrole: setting $name=$value"
            DOTFILES_ROLE_CHANGE="$name" chezmoi init --promptBool "${name}=${value}" || return 1
            chezmoi apply
            ;;
        *)
            echo "usage: cmrole [list|add <name>|remove <name>]" >&2
            return 1
            ;;
    esac
}
