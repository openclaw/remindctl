#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "Usage: $0 <vX.Y.Z> <draft|published> <release-proof.json>" >&2
  exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/release-config.sh
source "$ROOT/scripts/release-config.sh"

TAG="$1"
STATE="$2"
PROOF="$3"
GH_BIN=${GH_BIN:-gh}

case "$STATE" in
  draft) expected_draft=true ;;
  published) expected_draft=false ;;
  *)
    echo "Release state must be draft or published" >&2
    exit 1
    ;;
esac
if [[ ! -f "$PROOF" || -L "$PROOF" ]]; then
  echo "Expected a regular release-proof file: $PROOF" >&2
  exit 1
fi

pages="$(mktemp "${TMPDIR:-/tmp}/remindctl-release-pages.XXXXXX")"
cleanup() {
  rm -f "$pages"
}
trap cleanup EXIT
"$GH_BIN" api --paginate --slurp \
  "repos/$RELEASE_REPOSITORY/releases?per_page=100" >"$pages"

python3 - "$pages" "$PROOF" "$RELEASE_REPOSITORY" "$TAG" "$expected_draft" <<'PY'
import hashlib
import json
import sys

pages_path, proof_path, repository, tag, expected_draft_raw = sys.argv[1:]
with open(pages_path, encoding="utf-8") as handle:
    pages = json.load(handle)
with open(proof_path, encoding="utf-8") as handle:
    expected = json.load(handle)
releases = []
for page in pages:
    if isinstance(page, list):
        releases.extend(page)
    elif isinstance(page, dict):
        releases.append(page)
    else:
        raise SystemExit("malformed paginated release inventory")
matches = [release for release in releases if release.get("tag_name") == tag]
if len(matches) != 1:
    raise SystemExit(f"expected exactly one release for {tag}; found {len(matches)}")
release = matches[0]
actual = {
    "schemaVersion": 1,
    "repository": repository,
    "releaseId": release.get("id"),
    "tag": release.get("tag_name"),
    "title": release.get("name"),
    "bodySha256": hashlib.sha256(release.get("body", "").encode()).hexdigest(),
    "targetCommitish": release.get("target_commitish"),
    "draft": release.get("draft"),
    "prerelease": release.get("prerelease"),
    "updatedAt": release.get("updated_at"),
    "assets": [
        {
            "name": asset.get("name"),
            "id": asset.get("id"),
            "size": asset.get("size"),
            "digest": asset.get("digest"),
            "updatedAt": asset.get("updated_at"),
        }
        for asset in sorted(release.get("assets", []), key=lambda item: item.get("name", ""))
    ],
}
if actual["draft"] is not (expected_draft_raw == "true") or actual["prerelease"] is not False:
    raise SystemExit("release state changed")
if actual != expected:
    raise SystemExit("release metadata or exact asset identities changed after verification")
print(actual["releaseId"])
PY
