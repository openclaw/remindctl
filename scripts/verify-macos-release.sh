#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <vX.Y.Z> <asset-directory>" >&2
  exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/release-config.sh
source "$ROOT/scripts/release-config.sh"

TAG="$1"
ASSET_DIR="$2"
VERSION="${TAG#v}"
VERIFY_BINARY=${VERIFY_BINARY:-"$ROOT/scripts/verify-macos-binary.sh"}
SOURCE_PREFLIGHT=${SOURCE_PREFLIGHT:-"$ROOT/scripts/check-release-source.sh"}

if [[ ! "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Release tag must look like vX.Y.Z: $TAG" >&2
  exit 1
fi
if [[ ! -d "$ASSET_DIR" ]]; then
  echo "Missing release asset directory: $ASSET_DIR" >&2
  exit 1
fi

work="$(mktemp -d "${TMPDIR:-/tmp}/remindctl-release-verify.XXXXXX")"
cleanup() {
  rm -rf "$work"
}
trap cleanup EXIT

if [[ -n "${SOURCE_PROOF_FILE:-}" ]]; then
  if [[ ! -f "$SOURCE_PROOF_FILE" || -L "$SOURCE_PROOF_FILE" ]]; then
    echo "Expected a regular source-proof file: $SOURCE_PROOF_FILE" >&2
    exit 1
  fi
  source_proof="$SOURCE_PROOF_FILE"
else
  source_proof="$work/source-proof.json"
  "$SOURCE_PREFLIGHT" "$TAG" "$source_proof"
fi

python3 - "$ASSET_DIR" "$RELEASE_ARTIFACT" "$RELEASE_CHECKSUMS" "$RELEASE_INVENTORY" <<'PY'
import os
import sys

root, *expected = sys.argv[1:]
actual = []
for directory, dirs, files in os.walk(root):
    dirs.sort()
    files.sort()
    for name in files:
        actual.append(os.path.relpath(os.path.join(directory, name), root))
    for name in dirs:
        path = os.path.join(directory, name)
        if os.path.islink(path):
            actual.append(os.path.relpath(path, root))
if sorted(actual) != sorted(expected):
    raise SystemExit(f"unexpected release asset inventory: {actual!r}; expected {sorted(expected)!r}")
PY

artifact="$ASSET_DIR/$RELEASE_ARTIFACT"
checksums="$ASSET_DIR/$RELEASE_CHECKSUMS"
inventory="$ASSET_DIR/$RELEASE_INVENTORY"
artifact_sha="$(shasum -a 256 "$artifact" | awk '{print $1}')"
artifact_size="$(stat -f '%z' "$artifact")"

python3 - \
  "$inventory" "$TAG" "$VERSION" "$RELEASE_REPOSITORY" "$RELEASE_IDENTIFIER" \
  "$RELEASE_TEAM_ID" "$RELEASE_ARTIFACT" "$artifact_sha" "$artifact_size" \
  "$source_proof" "$RELEASE_DEFAULT_BRANCH" <<'PY'
import json
import re
import sys

(
    path,
    tag,
    version,
    repository,
    identifier,
    team_identifier,
    artifact_name,
    artifact_sha,
    artifact_size,
    source_proof_path,
    default_branch,
) = sys.argv[1:]

with open(path, encoding="utf-8") as handle:
    value = json.load(handle)
with open(source_proof_path, encoding="utf-8") as handle:
    source_proof = json.load(handle)

expected_proof_keys = {
    "schemaVersion",
    "repository",
    "defaultBranch",
    "tag",
    "tagObject",
    "sourceCommit",
    "signedTagVerified",
}
if set(source_proof) != expected_proof_keys:
    raise SystemExit(f"invalid source-proof keys: {sorted(source_proof)}")
expected_proof_values = {
    "schemaVersion": 1,
    "repository": repository,
    "defaultBranch": default_branch,
    "tag": tag,
    "signedTagVerified": True,
}
if any(source_proof[key] != expected for key, expected in expected_proof_values.items()):
    raise SystemExit("source proof does not match the requested release")
for key in ("tagObject", "sourceCommit"):
    if not isinstance(source_proof[key], str) or re.fullmatch(r"[0-9a-f]{40}", source_proof[key]) is None:
        raise SystemExit(f"invalid source-proof {key}")

expected_keys = {
    "schemaVersion",
    "tag",
    "tagObject",
    "sourceCommit",
    "version",
    "repository",
    "identifier",
    "teamIdentifier",
    "architectures",
    "assets",
}
if set(value) != expected_keys:
    raise SystemExit(f"invalid inventory keys: {sorted(value)}")
if value["schemaVersion"] != 1:
    raise SystemExit("unsupported inventory schema")
expected_values = {
    "tag": tag,
    "tagObject": source_proof["tagObject"],
    "sourceCommit": source_proof["sourceCommit"],
    "version": version,
    "repository": repository,
    "identifier": identifier,
    "teamIdentifier": team_identifier,
    "architectures": ["arm64", "x86_64"],
}
for key, expected in expected_values.items():
    if value[key] != expected:
        raise SystemExit(f"invalid inventory {key}: {value[key]!r}")
expected_asset = {
    "name": artifact_name,
    "sha256": artifact_sha,
    "size": int(artifact_size),
}
if value["assets"] != [expected_asset]:
    raise SystemExit(f"invalid inventory assets: {value['assets']!r}")
PY

python3 - "$checksums" "$RELEASE_ARTIFACT" "$artifact_sha" <<'PY'
import re
import sys

path, artifact, expected_sha = sys.argv[1:]
with open(path, encoding="utf-8") as handle:
    content = handle.read()
expected = f"{expected_sha}  {artifact}\n"
if content != expected or not re.fullmatch(r"[0-9a-f]{64}  [A-Za-z0-9._-]+\n", content):
    raise SystemExit("checksums.txt must contain exactly the expected artifact checksum")
PY

(
  cd "$ASSET_DIR"
  shasum -a 256 -c "$RELEASE_CHECKSUMS"
)

entries="$(zipinfo -1 "$artifact")"
if [[ "$entries" != "remindctl" ]]; then
  printf 'Unexpected archive entries:\n%s\n' "$entries" >&2
  exit 1
fi

extract_dir="$work/extracted"
mkdir "$extract_dir"
ditto -x -k "$artifact" "$extract_dir"

"$VERIFY_BINARY" "$extract_dir/remindctl" "$VERSION"
echo "Verified exact release asset inventory for $TAG"
