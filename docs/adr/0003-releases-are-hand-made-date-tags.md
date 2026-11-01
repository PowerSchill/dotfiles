# Releases are hand-made date tags with a local notes preview

A Release is a date tag such as `v2026.10.31`, created when you decide, with `mise run release:tag --yes`. The task only adds guardrails: it
refuses off `main`, on a dirty tree, when `main` differs from origin, or for an existing tag, because
the `v*` tag push also publishes the dev container image. `mise run release:preview` prints
the notes for the commits since the previous Release with git-cliff, to stdout only: nothing is
tagged, committed or published by the preview, and it works offline. Dotfiles have no API whose compatibility a
semantic version could describe, and every change already reaches Machines through `chezmoi update`,
so a Release only marks a point worth naming.

## Considered Options

- **release-please** (briefly configured on main in 3f3f189): rejected. It opens release PRs, bumps
  semantic versions and maintains `CHANGELOG.md` from CI, which publishes on every merge and gives
  version numbers no meaning here.
- **cocogitto `cog bump`**: rejected for the same reason; cocogitto is kept only to validate commit
  messages.
