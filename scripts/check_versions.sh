#!/usr/bin/env bash
# Fails when a mod changed since the previous release but kept its VERSION, so every release
# tells drivers and servers which mods moved. New mods pass.
# Usage: scripts/check_versions.sh [commit]
set -euo pipefail
cd "$(dirname "$0")/.."
. scripts/lib.sh

rev="${1:-HEAD}"
previous=$(previous_release "$rev")
if [ -z "$previous" ]; then
  echo "No previous release: nothing to compare."
  exit 0
fi

failed=0
for mod in $(mods "$rev"); do
  before=$(mod_version "$previous" "$mod")
  after=$(mod_version "$rev" "$mod")
  if [ -z "$after" ]; then
    echo "$mod: no VERSION in manifest.ini." >&2
    failed=1
  elif [ -z "$before" ]; then
    echo "$mod $after: new since $previous."
  elif git diff --quiet "$previous" "$rev" -- "$APPS/$mod"; then
    echo "$mod $after: unchanged since $previous."
  elif [ "$before" = "$after" ]; then
    echo "$mod changed since $previous but is still $after: bump VERSION in $APPS/$mod/manifest.ini." >&2
    failed=1
  else
    echo "$mod: $before -> $after."
  fi
done
exit "$failed"
