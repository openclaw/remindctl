#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "Usage: $0 <vX.Y.Z> <draft|published> <output-directory>" >&2
  exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/release-config.sh
source "$ROOT/scripts/release-config.sh"

TAG="$1"
STATE="$2"
OUTPUT_DIR="$3"
VERSION="${TAG#v}"
GH_BIN=${GH_BIN:-gh}

if [[ ! "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Release tag must look like vX.Y.Z: $TAG" >&2
  exit 1
fi
case "$STATE" in
  draft) expected_draft=true ;;
  published) expected_draft=false ;;
  *)
    echo "Release state must be draft or published" >&2
    exit 1
    ;;
esac
if [[ "${REQUIRE_GH_TOKEN:-0}" == "1" && -z "${GH_TOKEN:-}" ]]; then
  echo "GH_TOKEN is required only for the protected draft download step" >&2
  exit 1
fi
if [[ -e "$OUTPUT_DIR" ]]; then
  echo "Refusing to replace output directory: $OUTPUT_DIR" >&2
  exit 1
fi

parent="$(dirname "$OUTPUT_DIR")"
name="$(basename "$OUTPUT_DIR")"
mkdir -p "$parent"
work="$(mktemp -d "$parent/.${name}.XXXXXX")"
payload="$work/output"
assets="$payload/assets"
temp="$work/temp"
mkdir -p "$assets" "$temp"

cleanup() {
  rm -rf "$work"
}
trap cleanup EXIT

release_pages="$temp/releases.json"
selected_release="$temp/selected-release.json"
asset_rows="$temp/assets.tsv"
expected_notes="$temp/notes.md"
"$ROOT/scripts/extract-release-notes.sh" "$VERSION" "$expected_notes"

"$GH_BIN" api --paginate --slurp \
  "repos/$RELEASE_REPOSITORY/releases?per_page=100" >"$release_pages"

python3 - \
  "$release_pages" "$selected_release" "$asset_rows" "$expected_notes" \
  "$TAG" "$expected_draft" "$VERSION" \
  "$RELEASE_ARTIFACT" "$RELEASE_CHECKSUMS" "$RELEASE_INVENTORY" <<'PY'
import json
import sys

(
    pages_path,
    selected_path,
    rows_path,
    notes_path,
    tag,
    expected_draft_raw,
    version,
    *expected_names,
) = sys.argv[1:]
with open(pages_path, encoding="utf-8") as handle:
    value = json.load(handle)
with open(notes_path, encoding="utf-8") as handle:
    expected_notes = handle.read()
if not isinstance(value, list):
    raise SystemExit("release inventory response must be an array")
releases = []
for page in value:
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
expected_draft = expected_draft_raw == "true"
if release.get("draft") is not expected_draft or release.get("prerelease") is not False:
    raise SystemExit("release state does not match the requested draft/published state")
if release.get("name") != f"remindctl {version}":
    raise SystemExit("release title does not match the exact version")
if release.get("body") != expected_notes:
    raise SystemExit("release body does not exactly match CHANGELOG.md")
assets = release.get("assets")
if not isinstance(assets, list):
    raise SystemExit("release assets must be an array")
actual_names = [asset.get("name") for asset in assets if isinstance(asset, dict)]
if sorted(actual_names) != sorted(expected_names) or len(actual_names) != len(expected_names):
    raise SystemExit(f"unexpected release assets: {actual_names!r}")
for asset in sorted(assets, key=lambda item: item["name"]):
    asset_id = asset.get("id")
    size = asset.get("size")
    if not isinstance(asset_id, int) or asset_id <= 0 or not isinstance(size, int) or size <= 0:
        raise SystemExit(f"invalid asset metadata for {asset.get('name')!r}")
with open(selected_path, "w", encoding="utf-8") as handle:
    json.dump(release, handle)
with open(rows_path, "w", encoding="utf-8") as handle:
    for asset in sorted(assets, key=lambda item: item["name"]):
        handle.write(f"{asset['name']}\t{asset['id']}\t{asset['size']}\n")
PY

while IFS=$'\t' read -r asset_name asset_id expected_size; do
  "$GH_BIN" api "repos/$RELEASE_REPOSITORY/releases/assets/$asset_id" \
    -H 'Accept: application/octet-stream' >"$assets/$asset_name"
  actual_size="$(stat -f '%z' "$assets/$asset_name")"
  if [[ "$actual_size" != "$expected_size" ]]; then
    echo "Downloaded asset size changed: $asset_name" >&2
    exit 1
  fi
done <"$asset_rows"

inventory="$assets/$RELEASE_INVENTORY"
read -r source_commit tag_object < <(python3 - "$inventory" <<'PY'
import json
import re
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    value = json.load(handle)
result = []
for key in ("sourceCommit", "tagObject"):
    item = value.get(key)
    if not isinstance(item, str) or re.fullmatch(r"[0-9a-f]{40}", item) is None:
        raise SystemExit(f"invalid inventory {key}")
    result.append(item)
print(*result)
PY
)

"$GH_BIN" api "repos/$RELEASE_REPOSITORY" >"$temp/repository.json"
"$GH_BIN" api "repos/$RELEASE_REPOSITORY/git/ref/heads/$RELEASE_DEFAULT_BRANCH" >"$temp/default-ref.json"
"$GH_BIN" api "repos/$RELEASE_REPOSITORY/git/ref/tags/$TAG" >"$temp/tag-ref.json"
"$GH_BIN" api "repos/$RELEASE_REPOSITORY/git/tags/$tag_object" >"$temp/tag-object.json"

python3 - \
  "$payload/source-proof.json" "$payload/release-proof.json" \
  "$selected_release" "$temp/repository.json" \
  "$temp/default-ref.json" "$temp/tag-ref.json" "$temp/tag-object.json" \
  "$RELEASE_REPOSITORY" "$RELEASE_DEFAULT_BRANCH" "$TAG" \
  "$source_commit" "$tag_object" "${TRUSTED_WORKFLOW_SHA:-}" <<'PY'
import json
import hashlib
import re
import sys

(
    output_path,
    release_proof_path,
    release_path,
    repository_path,
    default_ref_path,
    tag_ref_path,
    tag_object_path,
    repository_name,
    default_branch,
    tag,
    source_commit,
    tag_object,
    trusted_workflow_sha,
) = sys.argv[1:]

def load(path):
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)

release = load(release_path)
repository = load(repository_path)
default_ref = load(default_ref_path)
tag_ref = load(tag_ref_path)
remote_tag = load(tag_object_path)
if repository.get("full_name") != repository_name or repository.get("default_branch") != default_branch:
    raise SystemExit("repository identity or default branch changed")
if default_ref.get("ref") != f"refs/heads/{default_branch}":
    raise SystemExit("default branch ref changed")
if default_ref.get("object", {}).get("type") != "commit" or default_ref.get("object", {}).get("sha") != source_commit:
    raise SystemExit("release source is not the live remote default commit")
if trusted_workflow_sha:
    if re.fullmatch(r"[0-9a-f]{40}", trusted_workflow_sha) is None or trusted_workflow_sha != source_commit:
        raise SystemExit("trusted workflow SHA does not match the release source")
if release.get("target_commitish") != source_commit:
    raise SystemExit("release target does not match the source commit")
if tag_ref.get("ref") != f"refs/tags/{tag}":
    raise SystemExit("remote tag ref changed")
tag_ref_object = tag_ref.get("object", {})
if tag_ref_object.get("type") != "tag" or tag_ref_object.get("sha") != tag_object:
    raise SystemExit("remote tag ref does not identify the exact annotated tag object")
if remote_tag.get("tag") != tag:
    raise SystemExit("annotated tag name changed")
if remote_tag.get("object", {}).get("type") != "commit" or remote_tag.get("object", {}).get("sha") != source_commit:
    raise SystemExit("annotated tag does not peel to the source commit")
verification = remote_tag.get("verification", {})
if verification.get("verified") is not True or verification.get("reason") != "valid":
    raise SystemExit("GitHub did not verify the exact signed tag object")

proof = {
    "schemaVersion": 1,
    "repository": repository_name,
    "defaultBranch": default_branch,
    "tag": tag,
    "tagObject": tag_object,
    "sourceCommit": source_commit,
    "signedTagVerified": True,
}
with open(output_path, "w", encoding="utf-8") as handle:
    json.dump(proof, handle, indent=2, sort_keys=True)
    handle.write("\n")

release_id = release.get("id")
updated_at = release.get("updated_at")
if not isinstance(release_id, int) or release_id <= 0 or not isinstance(updated_at, str) or not updated_at:
    raise SystemExit("release identity metadata is incomplete")
release_proof = {
    "schemaVersion": 1,
    "repository": repository_name,
    "releaseId": release_id,
    "tag": tag,
    "title": release.get("name"),
    "bodySha256": hashlib.sha256(release.get("body", "").encode()).hexdigest(),
    "targetCommitish": release.get("target_commitish"),
    "draft": release.get("draft"),
    "prerelease": release.get("prerelease"),
    "updatedAt": updated_at,
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
with open(release_proof_path, "w", encoding="utf-8") as handle:
    json.dump(release_proof, handle, indent=2, sort_keys=True)
    handle.write("\n")
PY

mv "$payload" "$OUTPUT_DIR"
trap - EXIT
rm -rf "$work"
echo "Downloaded and source-bound exact $STATE release for $TAG"
