#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR=${OUTPUT_DIR:-"$ROOT/dist"}
ZIP_PATH=${ZIP_PATH:-"$OUTPUT_DIR/remindctl-macos.zip"}
CODESIGN_IDENTITY=${CODESIGN_IDENTITY:-"-"}
CODESIGN_IDENTIFIER=${CODESIGN_IDENTIFIER:-"com.steipete.remindctl"}
DITTO_BIN=${DITTO_BIN:-/usr/bin/ditto}
STAGE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/remindctl-dist.XXXXXX")"

cleanup() {
  rm -rf "$STAGE_DIR"
}
trap cleanup EXIT

mkdir -p "$OUTPUT_DIR"
rm -f "$OUTPUT_DIR/remindctl" "$ZIP_PATH"

"$ROOT/scripts/build-macos-universal.sh" "$OUTPUT_DIR/remindctl"

codesign --force --sign "$CODESIGN_IDENTITY" \
  --identifier "$CODESIGN_IDENTIFIER" \
  "$OUTPUT_DIR/remindctl"
codesign --verify --strict --verbose=2 "$OUTPUT_DIR/remindctl"

cp "$OUTPUT_DIR/remindctl" "$STAGE_DIR/remindctl"
(
  cd "$STAGE_DIR"
  "$DITTO_BIN" --norsrc -c -k remindctl "$ZIP_PATH"
)

"$ROOT/scripts/check-macos-artifact.sh" "$ZIP_PATH"
echo "Done: $ZIP_PATH"

