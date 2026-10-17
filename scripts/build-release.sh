#!/usr/bin/env bash
# Adapt the local universal builder to the shared workflow's OUTPUT_DIR contract.
set -euo pipefail
: "${OUTPUT_DIR:?OUTPUT_DIR is required}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
candidate=$(find /Applications -maxdepth 1 -name 'Xcode_26*.app' | sort -V | tail -1)
[[ -n "$candidate" ]] || { echo 'Xcode 26 is required' >&2; exit 1; }
export DEVELOPER_DIR="$candidate/Contents/Developer"
mkdir -p "$OUTPUT_DIR"
"$ROOT/scripts/build-macos-universal.sh" "$OUTPUT_DIR/remindctl"
chmod +x "$OUTPUT_DIR/remindctl"
