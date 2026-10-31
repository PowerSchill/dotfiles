# A Profile sizes the Toolchain and is separate from Roles

A Profile (`minimal` or `full`) decides how much of the repository's Toolchain gets installed. It
has no effect on which Roles a Machine has, and Roles have no effect on it. It is picked from the
environment (`CI`, `CODESPACES`, `REMOTE_CONTAINERS_IPC`, `/.dockerenv` → `minimal`; anything else
→ `full`), can be overridden with `DOTFILES_PROFILE`, and never looks at the hostname. Keeping it
separate means a CI runner can check every Role combination while installing only the `minimal`
Toolchain. We avoid the hostname because it changes with the network on macOS, the same reason
Roles stopped using it.

## Considered Options

- **Treat a Profile as a set of Roles** (minimal = ephemeral, full = dev + gui). Rejected: it mixes
  "what this checkout needs to work on the repo" with "what this Machine is for", and CI would
  lose the ability to dry-run full Role sets.
- **Choose by hostname.** Rejected: unstable on macOS and meaningless in containers.
