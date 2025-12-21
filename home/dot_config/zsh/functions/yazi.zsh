# ################################################################################
# Yazi - Terminal file manager with cd-on-exit functionality
# ################################################################################

# Wrapper function for yazi that changes directory on exit
# Usage: y [directory or yazi options]
function y() {
	# Check if yazi is installed
	if ! command -v yazi &>/dev/null; then
		echo "Error: yazi is not installed"
		return 1
	fi

	# Create temporary file for storing the target directory
	local tmp
	tmp="$(mktemp -t "yazi-cwd.XXXXXX")"

	if [[ ! -f "$tmp" ]]; then
		echo "Error: Failed to create temporary file"
		return 1
	fi

	# Ensure cleanup on exit, even if interrupted
	trap "rm -f -- '$tmp'" EXIT INT TERM

	# Launch yazi with all arguments and cwd-file option
	yazi "$@" --cwd-file="$tmp"
	local exit_code=$?

	# Read the target directory from the temporary file
	local cwd
	if [[ -s "$tmp" ]]; then
		cwd="$(<"$tmp")"
	fi

	# Change to the target directory if it's different from current
	if [[ -n "$cwd" ]] && [[ "$cwd" != "$PWD" ]] && [[ -d "$cwd" ]]; then
		builtin cd -- "$cwd" || return 1
	fi

	# Cleanup
	rm -f -- "$tmp"
	trap - EXIT INT TERM

	return $exit_code
}
