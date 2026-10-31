# shellcheck shell=bash
# Shared helpers for the requirement acceptance tests (one .bats file per requirement).
#
# Linux tests run in a throwaway container that receives the *working tree*
# (tracked and untracked, non-ignored files), so uncommitted changes are tested.
# The repo is committed inside the container as a fresh git repo, because a
# worktree's .git file points at a host path the container cannot see.

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
ACCEPTANCE_IMAGE="${ACCEPTANCE_IMAGE:-ubuntu:24.04}"
# Not root/ubuntu/vagrant/vscode, so chezmoi does not detect an Ephemeral machine by username.
CONTAINER_USER="dev"
CONTAINER_REPO="/home/$CONTAINER_USER/dotfiles"

require_docker() {
  if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
    echo "docker is required for this acceptance test (install Docker and start the daemon)" >&2
    return 1
  fi
}

# Start a clean container with only git, curl and CA certificates, plus a copy of the repo.
# Extra arguments are passed to `docker run` (for example `-e CI=true`).
container_start() {
  require_docker
  CONTAINER="dotfiles-acceptance-$(basename "$BATS_TEST_FILENAME" .bats)-$$"
  export CONTAINER
  docker run -d --rm --name "$CONTAINER" "$@" "$ACCEPTANCE_IMAGE" sleep infinity >/dev/null

  container_root 'apt-get update -qq &&
        DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
            git curl ca-certificates >/dev/null &&
        useradd -m '"$CONTAINER_USER"

  (cd "$REPO_ROOT" && git ls-files -z --cached --others --exclude-standard |
    COPYFILE_DISABLE=1 tar --no-xattrs --no-mac-metadata --null -T - -cf -) |
    docker exec -i -u "$CONTAINER_USER" "$CONTAINER" \
      bash -c "mkdir -p $CONTAINER_REPO && tar -xf - -C $CONTAINER_REPO"

  container_exec 'git init -q -b main &&
        git -c user.name=test -c user.email=acceptance-test add -A &&
        git -c user.name=test -c user.email=acceptance-test commit -q -m "test: snapshot"'
}

container_stop() {
  [[ -n "${CONTAINER:-}" ]] && docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
}

container_root() {
  docker exec -u root "$CONTAINER" bash -c "$1"
}

# Run a command as the unprivileged user inside the repo, stdin closed so any prompt fails.
container_exec() {
  docker exec -u "$CONTAINER_USER" -w "$CONTAINER_REPO" \
    -e HOME="/home/$CONTAINER_USER" \
    -e PATH="/home/$CONTAINER_USER/.local/bin:/home/$CONTAINER_USER/.local/share/mise/shims:/usr/local/bin:/usr/bin:/bin" \
    "$CONTAINER" bash -c "$1" </dev/null
}

# Pinned version of a tool from a manifest file (default mise.toml).
pinned_version() {
  local tool="$1" file="${2:-mise.toml}"
  sed -n "s/^\"\{0,1\}$tool\"\{0,1\} *= *\"\([^\"]*\)\".*/\1/p" "$REPO_ROOT/$file"
}

# Run dotfiles-profile on the host with a controlled environment.
host_profile() {
  env -i PATH="$PATH" DOTFILES_CONTAINER_MARKERS="${DOTFILES_CONTAINER_MARKERS:-/nonexistent}" \
    "$@" "$REPO_ROOT/tools/bin/dotfiles-profile"
}

# Copy the working tree into a fresh git repo under the test's temp dir, on the
# host, and cd into it. For tests that need git hooks or a repo they can break.
scratch_repo() {
  SCRATCH="$BATS_TEST_TMPDIR/repo"
  export SCRATCH
  mkdir -p "$SCRATCH"
  (cd "$REPO_ROOT" && git ls-files -z --cached --others --exclude-standard |
    COPYFILE_DISABLE=1 tar --null -T - -cf -) | tar -xf - -C "$SCRATCH"
  cd "$SCRATCH" || return 1
  git init -q -b main
  git -c user.name=test -c user.email=acceptance-test add -A
  git -c user.name=test -c user.email=acceptance-test commit -q --no-verify -m "test: snapshot"
  export MISE_TRUSTED_CONFIG_PATHS="$SCRATCH${MISE_TRUSTED_CONFIG_PATHS:+:$MISE_TRUSTED_CONFIG_PATHS}"
  export MISE_YES=1
}

commit_in_scratch() {
  git -c user.name=test -c user.email=acceptance-test commit -q "$@"
}
