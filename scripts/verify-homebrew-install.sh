#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <vX.Y.Z>" >&2
  exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TAG="$1"
VERSION="${TAG#v}"
BREW_BIN=${BREW_BIN:-brew}
prefix="$($BREW_BIN --prefix steipete/tap/remindctl)"
binary="$prefix/bin/remindctl"

env -u GH_TOKEN -u GITHUB_TOKEN -u HOMEBREW_GITHUB_API_TOKEN \
  "$ROOT/scripts/verify-macos-binary.sh" "$binary" "$VERSION"
echo "Verified steipete/tap/remindctl downstream install for $TAG"
