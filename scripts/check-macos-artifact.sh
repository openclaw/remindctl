#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <remindctl-binary-or-zip>" >&2
  exit 1
fi

ARTIFACT="$1"
ARCHES_VALUE=${ARCHES:-"arm64 x86_64"}
read -r -a ARCH_LIST <<< "$ARCHES_VALUE"

if [[ ${#ARCH_LIST[@]} -eq 0 ]]; then
  echo "ARCHES must include at least one architecture" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/remindctl-artifact.XXXXXX")"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

if [[ "$ARTIFACT" == *.zip ]]; then
  unzip -q "$ARTIFACT" -d "$TMP_DIR"
  BINARY="$TMP_DIR/remindctl"
else
  BINARY="$ARTIFACT"
fi

if [[ ! -f "$BINARY" ]]; then
  echo "Expected remindctl binary not found in artifact: $ARTIFACT" >&2
  exit 1
fi

lipo "$BINARY" -verify_arch "${ARCH_LIST[@]}"
lipo -info "$BINARY"
file "$BINARY"
