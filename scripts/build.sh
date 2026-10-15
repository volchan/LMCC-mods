#!/usr/bin/env bash
# Packages every mod of apps/lua into dist/LMCC-mods-<release>.zip for drivers. The zip holds
# apps/lua/<mod>/ so it extracts into the AC root or drops into Content Manager.
# Built from a commit (default HEAD) only, so local edits never leak into a release, and with
# line endings as committed so the server checksums are stable. Mod versions are left as written
# in their manifests; the release version comes from the commit (scripts/version.sh).
# Usage: scripts/build.sh [commit]
set -euo pipefail
cd "$(dirname "$0")/.."
. scripts/lib.sh

rev="${1:-HEAD}"
if [ "$rev" = HEAD ] && [ -n "$(git status --porcelain -- "$APPS")" ]; then
  echo "Uncommitted changes in $APPS. Commit them first." >&2
  exit 1
fi

version=$(release_version "$rev")
zip="dist/LMCC-mods-$version.zip"
mkdir -p dist
# autocrlf off: Windows builds would otherwise zip CRLF files and change the checksums.
git -c core.autocrlf=false archive --format=zip --output="$zip" "$rev" "$APPS"

echo "Built $zip"
for mod in $(mods "$rev"); do
  echo "$mod $(mod_version "$rev" "$mod"): server checksum $(mod_checksum "$rev" "$mod")"
done
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "zip=$zip"
    echo "version=$version"
  } >> "$GITHUB_OUTPUT"
fi
