#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <remindctl-binary> <version>" >&2
  exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/release-config.sh
source "$ROOT/scripts/release-config.sh"

BINARY="$1"
VERSION="$2"
CODESIGN_BIN=${CODESIGN_BIN:-codesign}
CSREQ_BIN=${CSREQ_BIN:-csreq}
LIPO_BIN=${LIPO_BIN:-lipo}
OTOOL_BIN=${OTOOL_BIN:-otool}
PLIST_BUDDY_BIN=${PLIST_BUDDY_BIN:-/usr/libexec/PlistBuddy}

if [[ ! -f "$BINARY" || -L "$BINARY" || ! -x "$BINARY" ]]; then
  echo "Expected an executable regular file: $BINARY" >&2
  exit 1
fi

for token_name in \
  GH_TOKEN GITHUB_TOKEN HOMEBREW_GITHUB_API_TOKEN \
  ACTIONS_RUNTIME_TOKEN ACTIONS_ID_TOKEN_REQUEST_TOKEN; do
  if [[ -n "${!token_name+x}" ]]; then
    echo "Refusing to verify or execute a release binary while $token_name is present" >&2
    exit 1
  fi
done

actual_architectures="$($LIPO_BIN -archs "$BINARY")"
actual_architectures="$(printf '%s\n' "$actual_architectures" | tr ' ' '\n' | LC_ALL=C sort | xargs)"
expected_architectures="$(printf '%s\n' "$RELEASE_ARCHITECTURES" | tr ' ' '\n' | LC_ALL=C sort | xargs)"
if [[ "$actual_architectures" != "$expected_architectures" ]]; then
  echo "Unexpected architectures: $actual_architectures (expected $expected_architectures)" >&2
  exit 1
fi

expected_requirement="$($CSREQ_BIN -r="$RELEASE_DESIGNATED_REQUIREMENT" -t)"
plist_dir="$(mktemp -d "${TMPDIR:-/tmp}/remindctl-plist.XXXXXX")"
cleanup() {
  rm -rf "$plist_dir"
}
trap cleanup EXIT

read -r -a architectures <<<"$RELEASE_ARCHITECTURES"
for architecture in "${architectures[@]}"; do
  "$CODESIGN_BIN" --verify --strict --verbose=2 --arch "$architecture" "$BINARY"
  "$CODESIGN_BIN" --verify --strict --verbose=2 --arch "$architecture" \
    -R="$RELEASE_DESIGNATED_REQUIREMENT" "$BINARY"
  "$CODESIGN_BIN" --verify --strict --check-notarization --verbose=2 \
    --arch "$architecture" -R=notarized "$BINARY"

  signature="$($CODESIGN_BIN -dvvv --arch "$architecture" "$BINARY" 2>&1)"
  grep -Fxq "Identifier=$RELEASE_IDENTIFIER" <<<"$signature"
  grep -Fxq "TeamIdentifier=$RELEASE_TEAM_ID" <<<"$signature"
  grep -Fxq "Authority=$RELEASE_SIGNING_IDENTITY" <<<"$signature"
  grep -Eq '^CodeDirectory .*flags=.*\(runtime\)' <<<"$signature"
  timestamp="$(sed -n 's/^Timestamp=//p' <<<"$signature")"
  case "$timestamp" in
    "" | none | None | NONE)
      echo "The $architecture Developer ID signature has no secure timestamp" >&2
      exit 1
      ;;
  esac

  requirement="$($CODESIGN_BIN -d -r- --arch "$architecture" "$BINARY" 2>&1)"
  actual_requirement="$(sed -n 's/^designated => //p' <<<"$requirement")"
  if [[ "$actual_requirement" != "$expected_requirement" ]]; then
    echo "Unexpected $architecture designated requirement: $actual_requirement" >&2
    exit 1
  fi

  plist="$plist_dir/$architecture.plist"
  "$OTOOL_BIN" -arch "$architecture" -P "$BINARY" | sed -n '/^<?xml/,$p' >"$plist"
  if [[ ! -s "$plist" ]]; then
    echo "Missing $architecture embedded Info.plist" >&2
    exit 1
  fi
  if [[ "$($PLIST_BUDDY_BIN -c 'Print :CFBundleIdentifier' "$plist")" != "$RELEASE_IDENTIFIER" ]]; then
    echo "Unexpected $architecture embedded identifier" >&2
    exit 1
  fi
  if [[ "$($PLIST_BUDDY_BIN -c 'Print :CFBundleShortVersionString' "$plist")" != "$VERSION" \
    || "$($PLIST_BUDDY_BIN -c 'Print :CFBundleVersion' "$plist")" != "$VERSION" ]]; then
    echo "Unexpected $architecture embedded version" >&2
    exit 1
  fi
done

actual_version="$(env -u REMINDCTL_VERSION "$BINARY" --version)"
if [[ "$actual_version" != "$VERSION" ]]; then
  echo "Unexpected binary version: $actual_version (expected $VERSION)" >&2
  exit 1
fi

echo "Verified Developer ID metadata, online notarization constraint, and remindctl $VERSION ($actual_architectures)"
