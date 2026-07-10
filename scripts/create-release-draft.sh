#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <vX.Y.Z>" >&2
  exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/release-config.sh
source "$ROOT/scripts/release-config.sh"

TAG="$1"
VERSION="${TAG#v}"
ASSET_DIR=${ASSET_DIR:-"$ROOT/dist/release-$TAG"}
GH_BIN=${GH_BIN:-gh}
GIT_BIN=${GIT_BIN:-git}
RELEASE_CHECK_BIN=${RELEASE_CHECK_BIN:-"$ROOT/scripts/check-release.sh"}
RELEASE_VERIFY_BIN=${RELEASE_VERIFY_BIN:-"$ROOT/scripts/verify-macos-release.sh"}

run_gh() {
  env -u GH_TOKEN -u GITHUB_TOKEN -u HOMEBREW_GITHUB_API_TOKEN "$GH_BIN" "$@"
}

"$RELEASE_CHECK_BIN" "$TAG"
env -u GH_TOKEN -u GITHUB_TOKEN -u HOMEBREW_GITHUB_API_TOKEN \
  "$RELEASE_VERIFY_BIN" "$TAG" "$ASSET_DIR"

if [[ "$($GIT_BIN -C "$ROOT" branch --show-current)" != "$RELEASE_DEFAULT_BRANCH" ]]; then
  echo "Draft creation requires the $RELEASE_DEFAULT_BRANCH branch" >&2
  exit 1
fi
if [[ -n "$($GIT_BIN -C "$ROOT" status --porcelain)" ]]; then
  echo "Draft creation requires a clean checkout" >&2
  exit 1
fi
head_commit="$($GIT_BIN -C "$ROOT" rev-parse HEAD)"
if [[ "$head_commit" != "$($GIT_BIN -C "$ROOT" rev-parse "origin/$RELEASE_DEFAULT_BRANCH")" ]]; then
  echo "Draft creation requires HEAD == origin/$RELEASE_DEFAULT_BRANCH" >&2
  exit 1
fi
if ! "$GIT_BIN" -C "$ROOT" tag -v "$TAG" >/dev/null 2>&1; then
  echo "Draft creation requires a locally verified signed tag: $TAG" >&2
  exit 1
fi
if [[ "$($GIT_BIN -C "$ROOT" rev-list -n 1 "$TAG")" != "$head_commit" ]]; then
  echo "Release tag does not point at HEAD: $TAG" >&2
  exit 1
fi
remote_tag_commit="$($GIT_BIN -C "$ROOT" ls-remote origin "refs/tags/$TAG^{}" | awk 'NR == 1 {print $1}')"
if [[ -z "$remote_tag_commit" || "$remote_tag_commit" != "$head_commit" ]]; then
  echo "Remote signed tag is missing or does not point at HEAD: $TAG" >&2
  exit 1
fi

notes_file="$(mktemp "${TMPDIR:-/tmp}/remindctl-notes.XXXXXX")"
releases_file="$(mktemp "${TMPDIR:-/tmp}/remindctl-releases.XXXXXX")"
cleanup() {
  rm -f "$notes_file" "$releases_file"
}
trap cleanup EXIT
"$ROOT/scripts/extract-release-notes.sh" "$VERSION" "$notes_file"

run_gh api --paginate --slurp \
  "repos/$RELEASE_REPOSITORY/releases?per_page=100" >"$releases_file"
python3 - "$releases_file" "$TAG" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    value = json.load(handle)
releases = []
for page in value:
    releases.extend(page if isinstance(page, list) else [page])
if any(release.get("tag_name") == sys.argv[2] for release in releases):
    raise SystemExit(f"release already exists for {sys.argv[2]}")
PY

run_gh release create "$TAG" \
  "$ASSET_DIR/$RELEASE_ARTIFACT" \
  "$ASSET_DIR/$RELEASE_CHECKSUMS" \
  "$ASSET_DIR/$RELEASE_INVENTORY" \
  --repo "$RELEASE_REPOSITORY" \
  --draft \
  --verify-tag \
  --target "$head_commit" \
  --title "remindctl $VERSION" \
  --notes-file "$notes_file"

run_gh workflow run release.yml \
  --repo "$RELEASE_REPOSITORY" \
  --ref "$RELEASE_DEFAULT_BRANCH" \
  -f "tag=$TAG" \
  -f draft=true

echo "Draft created and protected verifier dispatched for $TAG; publication remains a separate gate"
