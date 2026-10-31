# mise tasks are the single definition of every Check

The Toolchain, its environment, and every chore live in one root `mise.toml`. Each Check is a
`mise run check:<name>` task. The pre-commit hooks (`repo: local`, `language: system`) and the CI
workflow only call those tasks and add no logic of their own, so the commit hook, CI, and a
developer's terminal can't drift apart. pre-commit, gitleaks, shellcheck and shfmt are pinned in
`mise.toml` and `mise.lock` rather than in `.pre-commit-config.yaml`, so every version is declared
in one place and Renovate can bump all of them.

## Considered Options

- **pre-commit runs the Checks, and CI calls `pre-commit run --all-files`.** Rejected: tool pins
  are split between two files, and the tasks can't be composed or given parameters.
- **hk** (a git-hook manager built for mise). Rejected for now: it adds Pkl as a config language,
  and pre-commit was already installed and familiar.
- **just or Taskfile plus asdf or aqua.** Rejected: two or three tools to cover what mise does in
  one file (tools, environment, tasks with dependencies, skipping when sources are unchanged).
