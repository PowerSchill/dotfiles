#!/usr/bin/env bash
# Create and push a Release: an annotated date tag on main (ADR 0003).
#
#   release-tag.sh [--tag vYYYY.MM.DD] [--yes]
#
# Refuses unless HEAD is main, the tree is clean, main matches origin/main and
# the tag is new. Without --yes it prints the notes and what it would do, then
# exits 1. Pushing a v* tag also publishes the dev container image.
set -euo pipefail

tag="v$(date +%Y.%m.%d)"
yes=false
while [ $# -gt 0 ]; do
  case "$1" in
    --tag)
      tag="${2:?release:tag: --tag needs a value}"
      shift 2
      ;;
    --yes)
      yes=true
      shift
      ;;
    *)
      echo "release:tag: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

die() {
  echo "release:tag: $*" >&2
  exit 1
}

[[ "$tag" =~ ^v[0-9]{4}\.[0-9]{2}\.[0-9]{2}$ ]] || die "tag must look like v2026.10.31, got: $tag"
[ "$(git rev-parse --abbrev-ref HEAD)" = main ] || die "not on main"
[ -z "$(git status --porcelain)" ] || die "working tree is not clean"
git fetch --quiet --tags origin main || die "could not fetch origin"
if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then die "tag $tag already exists"; fi
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] ||
  die "main differs from origin/main (push or pull first)"

if command -v git-cliff >/dev/null 2>&1; then
  git-cliff --config cliff.toml --unreleased --tag "$tag"
else
  echo "release:tag: git-cliff not installed, skipping notes (full Profile has it)" >&2
fi

if [ "$yes" != true ]; then
  echo "release:tag: refusing to tag $(git rev-parse --short HEAD) as $tag without --yes" >&2
  echo "  would run: git tag -a $tag -m $tag && git push origin $tag" >&2
  exit 1
fi

git tag -a "$tag" -m "$tag"
git push origin "refs/tags/$tag"
echo "release:tag: pushed $tag"
