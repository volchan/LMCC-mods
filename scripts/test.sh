#!/usr/bin/env bash
# Runs every test file with LuaJIT (what CSP runs), or the interpreter in $LUA.
# Usage: scripts/test.sh
set -euo pipefail
cd "$(dirname "$0")/.."

for f in tests/*_test.lua; do
  echo "== $f"
  "${LUA:-luajit}" "$f"
done
