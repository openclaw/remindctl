#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 vX.Y.Z" >&2
  exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TAG="$1"
VERSION="${TAG#v}"
# shellcheck source=version.env
source "$ROOT/version.env"

if [[ ! "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Release tag must look like vX.Y.Z" >&2
  exit 1
fi
if [[ "$MARKETING_VERSION" != "$VERSION" ]]; then
  echo "version.env MARKETING_VERSION=$MARKETING_VERSION does not match $VERSION" >&2
  exit 1
fi
package_version="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["version"])' "$ROOT/package.json")"
if [[ "$package_version" != "$VERSION" ]]; then
  echo "package.json version=$package_version does not match $VERSION" >&2
  exit 1
fi
if ! grep -Eq "^## $VERSION - [0-9]{4}-[0-9]{2}-[0-9]{2}$" "$ROOT/CHANGELOG.md"; then
  echo "CHANGELOG.md must contain a finalized $VERSION release section" >&2
  exit 1
fi
if ! grep -Fq "static let current = \"$VERSION\"" "$ROOT/Sources/remindctl/Version.swift"; then
  echo "Generated Version.swift is not synchronized" >&2
  exit 1
fi
if [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$ROOT/Sources/remindctl/Resources/Info.plist")" != "com.steipete.remindctl" ]]; then
  echo "Embedded identifier changed unexpectedly" >&2
  exit 1
fi
if [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/Sources/remindctl/Resources/Info.plist")" != "$VERSION" ]]; then
  echo "Embedded version is not synchronized" >&2
  exit 1
fi

notes_file="$(mktemp "${TMPDIR:-/tmp}/remindctl-notes.XXXXXX")"
trap 'rm -f "$notes_file"' EXIT
"$ROOT/scripts/extract-release-notes.sh" "$VERSION" "$notes_file"
"$ROOT/scripts/test-release.sh"

if rg -n 'github\.com/steipete/remindctl|repository=steipete/remindctl' \
  "$ROOT/README.md" "$ROOT/SKILL.md" "$ROOT/docs" \
  "$ROOT/scripts/update-homebrew.sh" "$ROOT/.github"; then
  echo "Found a non-canonical source repository URL" >&2
  exit 1
fi

echo "Credential-free release preflight OK: $TAG"
