# Homebrew is the primary Package installer on every Homebrew platform

Machines on a Homebrew platform (Homebrew Tier 1 or Tier 2, or WSL 2) get their Packages from one
shared list rendered into a Brewfile, so a Role means the same tools on macOS and every Linux distro.
Native packages remain only for what Homebrew needs first, such as build tools and the login shell,
and for what it cannot provide or what belongs to the system, such as a desktop stack. Homebrew has
no native Windows support, so Windows stays on winget. Tier 3 Machines, and Machines where Homebrew
cannot run (root outside a container, or no `sudo` to create its prefix), warn and skip Homebrew
rather than fail Apply.

Non-official Homebrew items are trusted one formula, cask or command at a time, because trusting a
whole tap gives that tap much wider reach on every Machine. A Check rejects a third-party entry that
has no matching trust declaration.

## Considered Options

- **Add Homebrew alongside the apt, dnf, snap, COPR and cargo lists**: rejected. It keeps several
  sources of truth, with the same Package under different names on each distro.
- **A shorter Package list for Linux**: rejected. It would bring back the platform differences this
  decision removes, at the cost of more disk and a slower first Apply on Linux.
- **Trust whole taps**: rejected. It is simpler to declare, but less safe if a tap is compromised.

## Consequences

- Existing Linux Machines keep their installed Native packages until someone removes them. Homebrew
  comes first on `PATH`, and nothing is uninstalled automatically.
- A Package that Homebrew renames or drops fails Apply until the list is fixed. Linux previously
  skipped unavailable Packages.
- Homebrew skips casks without Linux support with a warning, so a Linux Machine with the `gui` Role
  prints one warning for each of them.
