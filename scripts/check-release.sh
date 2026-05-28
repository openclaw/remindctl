#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 vX.Y.Z" >&2
  exit 1
fi

TAG="$1"
VERSION="${TAG#v}"

if [[ "$TAG" != v* || "$VERSION" == "$TAG" ]]; then
  echo "Release tag must look like vX.Y.Z" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/version.env"
if [[ "${MARKETING_VERSION:-}" != "$VERSION" ]]; then
  echo "version.env MARKETING_VERSION=${MARKETING_VERSION:-unset} does not match $VERSION" >&2
  exit 1
fi

notes_file="$(mktemp)"
trap 'rm -f "$notes_file"' EXIT
awk -v v="$VERSION" '
  $0 ~ ("^## " v "($|[[:space:]]-)") { in_section=1; next }
  in_section && $0 ~ "^## " { exit }
  in_section { print }
' "$ROOT/CHANGELOG.md" > "$notes_file"

if ! grep -q '[^[:space:]]' "$notes_file"; then
  echo "No CHANGELOG.md notes found for $VERSION" >&2
  exit 1
fi

if git -C "$ROOT" rev-parse "$TAG" >/dev/null 2>&1 \
  || git -C "$ROOT" ls-remote --exit-code --tags origin "$TAG" >/dev/null 2>&1; then
  echo "Tag already exists: $TAG" >&2
  exit 1
fi

if command -v gh >/dev/null 2>&1; then
  gh api repos/openclaw/remindctl/actions/workflows/release.yml --jq '.state' | grep -qx active
  gh secret list --repo openclaw/remindctl | awk '{print $1}' | grep -qx HOMEBREW_TAP_TOKEN
fi

echo "Release preflight OK: $TAG"
