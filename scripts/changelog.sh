#!/usr/bin/env bash
# Prints the changes drivers care about (breaking, feat, fix and perf commits) between the
# previous release and a commit, as Markdown for the release notes. An optional path keeps the
# commits touching it only, for the changelog of one mod.
# Usage: scripts/changelog.sh <commit> [path]
set -euo pipefail
cd "$(dirname "$0")/.."
. scripts/lib.sh

rev="${1:?usage: scripts/changelog.sh <commit> [path]}"
path="${2:-.}"
previous=$(previous_release "$rev")
range="${previous:+$previous..}$rev"
found=0

subjects() {
  git log --no-merges --pretty='%s' "$range" -- "$path"
}

# Prints one section: "#### <title>" then "- scope: subject" per matching commit.
section() {
  local title="$1" pattern="$2" lines
  lines=$(subjects | grep -E "$pattern" \
    | sed -E 's/^[a-z]+\(([^)]*)\)!?: /- \1: /; s/^[a-z]+!?: /- /' || true)
  if [ -n "$lines" ]; then
    printf '#### %s\n\n%s\n\n' "$title" "$lines"
    found=1
  fi
}

section 'Breaking changes' '^[a-z]+(\([^)]*\))?!: '
section Features '^feat(\([^)]*\))?: '
section Fixes '^fix(\([^)]*\))?: '
section Performance '^perf(\([^)]*\))?: '
if [ "$found" -eq 0 ]; then
  printf 'No driver-facing changes.\n\n'
fi
