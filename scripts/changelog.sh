#!/usr/bin/env bash
# Prints the changes drivers care about (feat, fix and perf commits) between the previous tag
# and TAG, as Markdown for the release notes.
# Usage: scripts/changelog.sh <tag>
set -euo pipefail

tag="${1:?usage: scripts/changelog.sh <tag>}"
previous=$(git describe --tags --abbrev=0 "$tag^" 2>/dev/null || true)
range="${previous:+$previous..}$tag"
found=0

# Prints one section: "### <title>" then "- scope: subject" per commit of <type>.
section() {
  local title="$1" type="$2" lines
  lines=$(git log --no-merges --pretty='%s' "$range" \
    | grep -E "^$type(\([^)]*\))?!?: " \
    | sed -E "s/^$type\(([^)]*)\)!?: /- \1: /; s/^$type!?: /- /" || true)
  if [ -n "$lines" ]; then
    printf '### %s\n\n%s\n\n' "$title" "$lines"
    found=1
  fi
}

section Features feat
section Fixes fix
section Performance perf
if [ "$found" -eq 0 ]; then
  echo "No driver-facing changes."
fi
