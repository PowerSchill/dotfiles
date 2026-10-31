#!/usr/bin/env bash
# Install this repo's git hooks. Each hook runs pre-commit through mise, so the
# pinned Toolchain (including pre-commit's Python) is used even when git runs
# without mise on PATH: a GUI client, or a fresh machine with no system python3.
#
# Replaces the hooks `pre-commit install` would write, which look for python3 or
# pre-commit on PATH. The hooks directory may be shared by several worktrees, so
# each hook finds its own checkout at run time.
set -euo pipefail

hooks_dir="$(git rev-parse --git-path hooks)"
mkdir -p "$hooks_dir"
for type in pre-commit commit-msg pre-push; do
  cat >"$hooks_dir/$type" <<HOOK
#!/usr/bin/env bash
# Installed by \`mise run hooks:install\` (tools/hooks/install.sh). Do not edit.
root="\$(git rev-parse --show-toplevel)"
exec "\$root/tools/hooks/mise-run" --exec pre-commit hook-impl \\
  --config=.pre-commit-config.yaml --hook-type=$type \\
  --hook-dir "\$(cd "\$(dirname "\$0")" && pwd)" -- "\$@"
HOOK
  chmod +x "$hooks_dir/$type"
  echo "hooks:install: installed $type"
done
