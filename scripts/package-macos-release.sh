#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/release-config.sh
source "$ROOT/scripts/release-config.sh"
# shellcheck source=version.env
source "$ROOT/version.env"

TAG=${1:-"v$MARKETING_VERSION"}
VERSION="${TAG#v}"
OUTPUT_DIR=${OUTPUT_DIR:-"$ROOT/dist/release-$TAG"}
BUILD_SCRIPT=${BUILD_SCRIPT:-"$ROOT/scripts/build-macos-universal.sh"}
CODESIGN_BIN=${CODESIGN_BIN:-codesign}
XCRUN_BIN=${XCRUN_BIN:-xcrun}
DITTO_BIN=${DITTO_BIN:-/usr/bin/ditto}
VERIFY_RELEASE=${VERIFY_RELEASE:-"$ROOT/scripts/verify-macos-release.sh"}
CHECK_ARTIFACT=${CHECK_ARTIFACT:-"$ROOT/scripts/check-macos-artifact.sh"}
SOURCE_PREFLIGHT=${SOURCE_PREFLIGHT:-"$ROOT/scripts/check-release-source.sh"}
CODESIGN_IDENTITY=${CODESIGN_IDENTITY:-"$RELEASE_SIGNING_IDENTITY"}
VERIFY_ATTEMPTS=${VERIFY_ATTEMPTS:-6}
VERIFY_DELAY_SECONDS=${VERIFY_DELAY_SECONDS:-10}

if [[ "$TAG" != "v$MARKETING_VERSION" || ! "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Tag $TAG does not match version.env ($MARKETING_VERSION)" >&2
  exit 1
fi
if [[ "$CODESIGN_IDENTITY" != "$RELEASE_SIGNING_IDENTITY" ]]; then
  echo "Official releases require $RELEASE_SIGNING_IDENTITY" >&2
  exit 1
fi
if [[ -z "${NOTARYTOOL_PROFILE:-}" ]]; then
  echo "Set NOTARYTOOL_PROFILE to a runtime Keychain profile before official packaging" >&2
  exit 1
fi
if [[ -e "$OUTPUT_DIR" ]]; then
  echo "Refusing to replace existing release output: $OUTPUT_DIR" >&2
  exit 1
fi

output_parent="$(dirname "$OUTPUT_DIR")"
output_name="$(basename "$OUTPUT_DIR")"
mkdir -p "$output_parent"
stage="$(mktemp -d "$output_parent/.${output_name}.XXXXXX")"
assets="$stage/assets"
notary_result="$(mktemp "${TMPDIR:-/tmp}/remindctl-notary.XXXXXX")"
source_proof_before="$(mktemp "${TMPDIR:-/tmp}/remindctl-source-before.XXXXXX")"
source_proof_after="$(mktemp "${TMPDIR:-/tmp}/remindctl-source-after.XXXXXX")"

cleanup() {
  rm -rf "$stage"
  rm -f "$notary_result" "$source_proof_before" "$source_proof_after"
}
trap cleanup EXIT

mkdir "$assets"

"$SOURCE_PREFLIGHT" "$TAG" "$source_proof_before"

SKIP_VERSION_SYNC=1 "$BUILD_SCRIPT" "$stage/remindctl"

"$CODESIGN_BIN" --force --timestamp --options runtime \
  --identifier "$RELEASE_IDENTIFIER" \
  --sign "$CODESIGN_IDENTITY" \
  "$stage/remindctl"
"$CODESIGN_BIN" --verify --strict --verbose=2 "$stage/remindctl"
"$CODESIGN_BIN" --verify --strict --verbose=2 \
  -R="$RELEASE_DESIGNATED_REQUIREMENT" \
  "$stage/remindctl"
"$CHECK_ARTIFACT" "$stage/remindctl"

(
  cd "$stage"
  "$DITTO_BIN" --norsrc -c -k remindctl "$assets/$RELEASE_ARTIFACT"
)
"$XCRUN_BIN" notarytool submit "$assets/$RELEASE_ARTIFACT" \
  --keychain-profile "$NOTARYTOOL_PROFILE" \
  --wait \
  --output-format json >"$notary_result"

python3 - "$notary_result" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    value = json.load(handle)
if value.get("status") != "Accepted" or not isinstance(value.get("id"), str) or not value["id"]:
    raise SystemExit(f"notarization was not accepted: {value.get('status')!r}")
PY

"$SOURCE_PREFLIGHT" "$TAG" "$source_proof_after"
if ! cmp -s "$source_proof_before" "$source_proof_after"; then
  echo "Release source or signed tag changed during packaging" >&2
  exit 1
fi

artifact_sha="$(shasum -a 256 "$assets/$RELEASE_ARTIFACT" | awk '{print $1}')"
artifact_size="$(stat -f '%z' "$assets/$RELEASE_ARTIFACT")"
printf '%s  %s\n' "$artifact_sha" "$RELEASE_ARTIFACT" >"$assets/$RELEASE_CHECKSUMS"
python3 - \
  "$assets/$RELEASE_INVENTORY" "$TAG" "$VERSION" "$RELEASE_REPOSITORY" \
  "$RELEASE_IDENTIFIER" "$RELEASE_TEAM_ID" "$RELEASE_ARTIFACT" \
  "$artifact_sha" "$artifact_size" "$source_proof_after" <<'PY'
import json
import sys

(
    path,
    tag,
    version,
    repository,
    identifier,
    team_identifier,
    artifact,
    sha256,
    size,
    source_proof_path,
) = sys.argv[1:]
with open(source_proof_path, encoding="utf-8") as handle:
    source_proof = json.load(handle)
value = {
    "schemaVersion": 1,
    "tag": tag,
    "tagObject": source_proof["tagObject"],
    "sourceCommit": source_proof["sourceCommit"],
    "version": version,
    "repository": repository,
    "identifier": identifier,
    "teamIdentifier": team_identifier,
    "architectures": ["arm64", "x86_64"],
    "assets": [{"name": artifact, "sha256": sha256, "size": int(size)}],
}
with open(path, "w", encoding="utf-8") as handle:
    json.dump(value, handle, indent=2, sort_keys=True)
    handle.write("\n")
PY

verified=0
for ((attempt = 1; attempt <= VERIFY_ATTEMPTS; attempt++)); do
  if env -u GH_TOKEN -u GITHUB_TOKEN -u HOMEBREW_GITHUB_API_TOKEN \
    SOURCE_PROOF_FILE="$source_proof_after" \
    "$VERIFY_RELEASE" "$TAG" "$assets"; then
    verified=1
    break
  fi
  if ((attempt < VERIFY_ATTEMPTS)); then
    echo "Online notarization constraint not satisfied yet; retrying verification ($attempt/$VERIFY_ATTEMPTS)" >&2
    sleep "$VERIFY_DELAY_SECONDS"
  fi
done
if [[ "$verified" != "1" ]]; then
  echo "Official release verification failed after notarization" >&2
  exit 1
fi

mv "$assets" "$OUTPUT_DIR"
cleanup
trap - EXIT
echo "Official signed and notarized assets: $OUTPUT_DIR"
