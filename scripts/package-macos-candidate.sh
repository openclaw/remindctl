#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/release-config.sh
source "$ROOT/scripts/release-config.sh"

OUTPUT=${1:-"$ROOT/dist/remindctl-macos-local.zip"}
BUILD_SCRIPT=${BUILD_SCRIPT:-"$ROOT/scripts/build-macos-universal.sh"}
CODESIGN_BIN=${CODESIGN_BIN:-codesign}
DITTO_BIN=${DITTO_BIN:-/usr/bin/ditto}
CHECK_ARTIFACT=${CHECK_ARTIFACT:-"$ROOT/scripts/check-macos-artifact.sh"}
stage="$(mktemp -d "${TMPDIR:-/tmp}/remindctl-local.XXXXXX")"

cleanup() {
  rm -rf "$stage"
}
trap cleanup EXIT

"$BUILD_SCRIPT" "$stage/remindctl"
"$CODESIGN_BIN" --force --sign - --identifier "$RELEASE_IDENTIFIER" "$stage/remindctl"
"$CODESIGN_BIN" --verify --strict --verbose=2 "$stage/remindctl"
"$CHECK_ARTIFACT" "$stage/remindctl"

mkdir -p "$(dirname "$OUTPUT")"
(
  cd "$stage"
  "$DITTO_BIN" --norsrc -c -k remindctl remindctl-macos-local.zip
)
mv -f "$stage/remindctl-macos-local.zip" "$OUTPUT"
echo "Local credential-free candidate: $OUTPUT"
