# Shared helpers of the release scripts. Source it: . "$(dirname "$0")/lib.sh"
# A release holds every mod of apps/lua; each mod keeps its own VERSION in its manifest.ini.

APPS=apps/lua

# Mod folder names at a commit, one per line.
mods() {
  git ls-tree -d --name-only "$1:$APPS"
}

# VERSION of a mod at a commit, empty when the mod does not exist there.
mod_version() {
  { git show "$1:$APPS/$2/manifest.ini" 2>/dev/null || true; } | sed -nE 's/^VERSION *= *([^ ;]+).*/\1/p' | tr -d '\r'
}

# MD5 of a mod manifest as committed, the file servers checksum.
mod_checksum() {
  git show "$1:$APPS/$2/manifest.ini" | md5sum | cut -d' ' -f1
}

# Release version of a commit: commit date in UTC, then its short hash (YYYY.MM.DD.abcdef0).
release_version() {
  local date sha
  date=$(TZ=UTC git log -1 --format=%cd --date=format-local:%Y.%m.%d "$1")
  sha=$(git rev-parse --short=7 "$1")
  echo "$date.$sha"
}

# Latest release tag strictly before a commit, empty for the first release.
previous_release() {
  git describe --tags --abbrev=0 --match 'v*' "$1^" 2>/dev/null || true
}
