#!/usr/bin/env bash
# Prints the release notes of a commit: every mod with its version, what moved since the
# previous release and the manifest checksum servers need, then the changelog of each mod.
# Usage: scripts/notes.sh <commit>
set -euo pipefail
cd "$(dirname "$0")/.."
. scripts/lib.sh

rev="${1:?usage: scripts/notes.sh <commit>}"
previous=$(previous_release "$rev")

echo "## Mods"
echo
echo "Every mod is required. Servers checksum each manifest below (Required Apps file, MD5)."
echo
echo "| Mod | Version | Since ${previous:-the start} | Required Apps file | MD5 |"
echo "|---|---|---|---|---|"
for mod in $(mods "$rev"); do
  after=$(mod_version "$rev" "$mod")
  before=$(mod_version "${previous:-$rev}" "$mod")
  if [ -z "$previous" ] || [ -z "$before" ]; then
    moved=new
  elif [ "$before" = "$after" ]; then
    moved=unchanged
  else
    moved="$before -> $after"
  fi
  echo "| $mod | $after | $moved | \`$APPS/$mod/manifest.ini\` | \`$(mod_checksum "$rev" "$mod")\` |"
done
echo
echo "## Changes"
echo
for mod in $(mods "$rev"); do
  echo "### $mod"
  echo
  scripts/changelog.sh "$rev" "$APPS/$mod"
done
