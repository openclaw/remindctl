#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <vX.Y.Z> <source-proof.json>" >&2
  exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/release-config.sh
source "$ROOT/scripts/release-config.sh"

TAG="$1"
OUTPUT="$2"
GIT_BIN=${GIT_BIN:-git}
SOURCE_REMOTE=${SOURCE_REMOTE:-origin}

if [[ ! "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Release tag must look like vX.Y.Z: $TAG" >&2
  exit 1
fi
if [[ -L "$OUTPUT" ]]; then
  echo "Refusing a symlink source-proof path: $OUTPUT" >&2
  exit 1
fi
if [[ "$($GIT_BIN -C "$ROOT" branch --show-current)" != "$RELEASE_DEFAULT_BRANCH" ]]; then
  echo "Official packaging requires the $RELEASE_DEFAULT_BRANCH branch" >&2
  exit 1
fi
if [[ -n "$($GIT_BIN -C "$ROOT" status --porcelain)" ]]; then
  echo "Official packaging requires a clean checkout" >&2
  exit 1
fi

head_commit="$($GIT_BIN -C "$ROOT" rev-parse HEAD)"
remote_head="$($GIT_BIN -C "$ROOT" ls-remote --symref "$SOURCE_REMOTE" HEAD)"
remote_default_ref="$(awk '$1 == "ref:" && $3 == "HEAD" {print $2}' <<<"$remote_head")"
remote_default_sha="$(awk '$2 == "HEAD" && $1 != "ref:" {print $1}' <<<"$remote_head")"
if [[ "$remote_default_ref" != "refs/heads/$RELEASE_DEFAULT_BRANCH" ]]; then
  echo "Unexpected live remote default branch: $remote_default_ref" >&2
  exit 1
fi
if [[ ! "$remote_default_sha" =~ ^[0-9a-f]{40}$ || "$remote_default_sha" != "$head_commit" ]]; then
  echo "HEAD does not match the live remote default SHA" >&2
  exit 1
fi

if [[ "$($GIT_BIN -C "$ROOT" cat-file -t "$TAG" 2>/dev/null || true)" != "tag" ]]; then
  echo "Release requires an annotated tag object: $TAG" >&2
  exit 1
fi
if ! "$GIT_BIN" -C "$ROOT" tag -v "$TAG" >/dev/null 2>&1; then
  echo "Release requires a locally verified signed tag: $TAG" >&2
  exit 1
fi
tag_object="$($GIT_BIN -C "$ROOT" rev-parse "$TAG^{tag}")"
tag_commit="$($GIT_BIN -C "$ROOT" rev-parse "$TAG^{commit}")"
if [[ "$tag_commit" != "$head_commit" ]]; then
  echo "Signed tag does not peel to the live default commit: $TAG" >&2
  exit 1
fi

remote_tags="$($GIT_BIN -C "$ROOT" ls-remote --tags "$SOURCE_REMOTE" \
  "refs/tags/$TAG" "refs/tags/$TAG^{}")"
remote_tag_object="$(awk -v ref="refs/tags/$TAG" '$2 == ref {print $1}' <<<"$remote_tags")"
remote_tag_commit="$(awk -v ref="refs/tags/$TAG^{}" '$2 == ref {print $1}' <<<"$remote_tags")"
if [[ "$remote_tag_object" != "$tag_object" || "$remote_tag_commit" != "$tag_commit" ]]; then
  echo "Remote signed tag object or peeled commit does not match local proof: $TAG" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT")"
stage="$(mktemp "$(dirname "$OUTPUT")/.source-proof.XXXXXX")"
cleanup() {
  rm -f "$stage"
}
trap cleanup EXIT
python3 - \
  "$stage" "$RELEASE_REPOSITORY" "$RELEASE_DEFAULT_BRANCH" "$TAG" \
  "$tag_object" "$tag_commit" <<'PY'
import json
import sys

path, repository, default_branch, tag, tag_object, source_commit = sys.argv[1:]
value = {
    "schemaVersion": 1,
    "repository": repository,
    "defaultBranch": default_branch,
    "tag": tag,
    "tagObject": tag_object,
    "sourceCommit": source_commit,
    "signedTagVerified": True,
}
with open(path, "w", encoding="utf-8") as handle:
    json.dump(value, handle, indent=2, sort_keys=True)
    handle.write("\n")
PY
mv -f "$stage" "$OUTPUT"
trap - EXIT
