#!/usr/bin/env bash
# Packages the app into dist/LmccFlags-<version>.zip for drivers. The zip holds
# apps/lua/LmccFlags/ so it extracts into the AC root or drops into Content Manager.
# Built from the committed tree only, so local edits never leak into a release.
# An optional version sets VERSION in the zipped manifest (the repo file is left alone); the
# release workflow passes the tag. Prints the MD5 of manifest.ini, the file servers checksum.
# Usage: scripts/build.sh [version]
set -euo pipefail

cd "$(dirname "$0")/.."
app=apps/lua/LmccFlags
manifest=$app/manifest.ini
version="${1:-}"

if [ -n "$(git status --porcelain -- "$app")" ]; then
  echo "Uncommitted changes in $app. Commit them first." >&2
  exit 1
fi

if [ -n "$version" ]; then
  if ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Version must look like 1.2.3, got '$version'." >&2
    exit 1
  fi
  # Store the edited manifest in a temporary index and archive that tree: no commit, no
  # working tree change, and line endings stay as committed so the checksum is stable.
  blob=$(git show "HEAD:$manifest" | sed -E "s/^VERSION *=.*/VERSION = $version/" | git hash-object -w --stdin)
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  export GIT_INDEX_FILE="$tmp/index"
  git read-tree HEAD
  git update-index --cacheinfo "100644,$blob,$manifest"
  tree=$(git write-tree)
  unset GIT_INDEX_FILE
else
  version=$(git show "HEAD:$manifest" | sed -nE 's/^VERSION *= *([0-9.]+).*/\1/p')
  tree=HEAD
fi

zip="dist/LmccFlags-$version.zip"
mkdir -p dist
# autocrlf off: Windows builds would otherwise zip CRLF files and change the checksum.
git -c core.autocrlf=false archive --format=zip --output="$zip" "$tree" "$app"
checksum=$(unzip -p "$zip" "$manifest" | md5sum | cut -d' ' -f1)

echo "Built $zip"
echo "Server checksum (MD5 of $manifest): $checksum"
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "zip=$zip"
    echo "version=$version"
    echo "checksum=$checksum"
  } >> "$GITHUB_OUTPUT"
fi
