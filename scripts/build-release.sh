#!/usr/bin/env bash
# Adapt the local universal builder to the shared workflow's OUTPUT_DIR contract.
set -euo pipefail
: "${OUTPUT_DIR:?OUTPUT_DIR is required}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export MACOSX_DEPLOYMENT_TARGET=14.0
mkdir -p "$OUTPUT_DIR"
"$ROOT/scripts/build-macos-universal.sh" "$OUTPUT_DIR/remindctl"
chmod +x "$OUTPUT_DIR/remindctl"
