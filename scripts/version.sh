#!/usr/bin/env bash
# Prints the release version of a commit (default HEAD): YYYY.MM.DD.<short hash>.
# Usage: scripts/version.sh [commit]
set -euo pipefail
cd "$(dirname "$0")/.."
. scripts/lib.sh

release_version "${1:-HEAD}"
