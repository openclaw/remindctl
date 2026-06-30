#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <output-binary>" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT="$1"
ARCHES_VALUE=${ARCHES:-"arm64 x86_64"}
read -r -a ARCH_LIST <<< "$ARCHES_VALUE"

if [[ ${#ARCH_LIST[@]} -eq 0 ]]; then
  echo "ARCHES must include at least one architecture" >&2
  exit 1
fi

if [[ "${SKIP_VERSION_SYNC:-0}" != "1" ]]; then
  "$ROOT/scripts/generate-version.sh"
fi

mkdir -p "$(dirname "$OUTPUT")"

BINARIES=()
for ARCH in "${ARCH_LIST[@]}"; do
  SCRATCH_PATH="$ROOT/.build/$ARCH"
  swift build -c release --product remindctl --arch "$ARCH" --scratch-path "$SCRATCH_PATH"

  BIN_PATH="$(
    swift build -c release --product remindctl --arch "$ARCH" \
      --scratch-path "$SCRATCH_PATH" --show-bin-path
  )"
  BINARY="$BIN_PATH/remindctl"
  if [[ ! -f "$BINARY" ]]; then
    echo "Expected build output not found: $BINARY" >&2
    exit 1
  fi

  BINARIES+=("$BINARY")
done

lipo -create "${BINARIES[@]}" -output "$OUTPUT"
for ARCH in "${ARCH_LIST[@]}"; do
  lipo "$OUTPUT" -verify_arch "$ARCH"
done
lipo -info "$OUTPUT"
