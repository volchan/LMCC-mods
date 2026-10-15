#!/usr/bin/env bash
# Tags the pushed HEAD of main with its release version and pushes the tag; the release
# workflow then builds and publishes it.
# Usage: scripts/release.sh
set -euo pipefail
cd "$(dirname "$0")/.."
. scripts/lib.sh

if [ -n "$(git status --porcelain)" ]; then
  echo "Uncommitted changes. Commit or stash them first." >&2
  exit 1
fi
if [ "$(git rev-parse --abbrev-ref HEAD)" != main ]; then
  echo "Releases are made from main." >&2
  exit 1
fi
git fetch --quiet origin main
if [ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ]; then
  echo "HEAD is not origin/main: push or pull first." >&2
  exit 1
fi

scripts/check_versions.sh HEAD
tag="v$(release_version HEAD)"
if git rev-parse -q --verify "refs/tags/$tag" > /dev/null; then
  echo "$tag already exists." >&2
  exit 1
fi
git tag -a "$tag" -m "LMCC mods ${tag#v}"
git push origin "$tag"
echo "Pushed $tag: the release workflow publishes it."
