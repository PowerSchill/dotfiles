# Dotfiles

Personal dotfiles that provision a machine's shell, editor, terminal, and CLI tools, plus the
tooling used to work on the repository itself.

## Machines

**Machine**:
A computer the dotfiles are applied to.
_Avoid_: host, box, target

**Package**:
A program the dotfiles install on a Machine for the person using it.
_Avoid_: tool, dependency

**Role**:
An opt-in capability a Machine has, chosen once and remembered (dev, gui, work, personal,
security, onepassword, homelab).
_Avoid_: profile, flavor, machine type

**Ephemeral machine**:
A Machine expected to be thrown away (container, Codespace, VM, CI runner), detected rather than
chosen. It gets only the dev Role.
_Avoid_: temporary machine, throwaway role

## Repository tooling

**Toolchain**:
The pinned set of programs needed to work on this repository (validate, test, preview, apply),
separate from the Packages it installs on Machines.
_Avoid_: dev tools, dependencies, packages

**Profile**:
How much of the Toolchain a checkout installs: `minimal` (provisioning and checks only) or `full`
(adds optional extras). It never affects which Roles a Machine has.
_Avoid_: role, mode, tier

**Check**:
A named verification that must pass before a commit is accepted, run identically by the commit
hook, CI, and a developer.
_Avoid_: lint, hook, test (when meaning the whole gate)

**Preview**:
A read-only comparison of what applying the dotfiles would change in the real home directory.
_Avoid_: diff, dry run

**Dry-run apply**:
Rendering the dotfiles into a scratch home directory for a given set of Roles, to prove they
apply cleanly without touching a real one.
_Avoid_: preview, test apply

**Apply**:
Writing the dotfiles into the real home directory; only ever done with explicit confirmation.
_Avoid_: install, deploy, sync

**Release**:
A date-named tag marking a point in the repository's history (for example `v2026.10.31`), created
by hand.
_Avoid_: version, deploy

**Release notes**:
A summary of the Conventional Commits made since the previous Release.
_Avoid_: changelog entry
