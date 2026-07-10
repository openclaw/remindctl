#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <version> <output-file>" >&2
  exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$1"
OUTPUT="$2"

awk -v version="$VERSION" '
  $0 ~ ("^## " version " - ") { in_section=1; next }
  in_section && $0 ~ "^## " { exit }
  in_section { print }
' "$ROOT/CHANGELOG.md" >"$OUTPUT"

if ! grep -q '[^[:space:]]' "$OUTPUT"; then
  echo "No CHANGELOG.md notes found for $VERSION" >&2
  exit 1
fi
