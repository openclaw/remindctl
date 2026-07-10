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
GH_BIN=${GH_BIN:-gh}
RELEASE_CHECK=${RELEASE_CHECK:-"$ROOT/scripts/check-release.sh"}
SOURCE_CHECK=${SOURCE_CHECK:-"$ROOT/scripts/check-release-source.sh"}
DOWNLOAD_RELEASE=${DOWNLOAD_RELEASE:-"$ROOT/scripts/download-release-assets.sh"}
VERIFY_RELEASE=${VERIFY_RELEASE:-"$ROOT/scripts/verify-macos-release.sh"}
CHECK_METADATA=${CHECK_METADATA:-"$ROOT/scripts/check-release-metadata.sh"}

work="$(mktemp -d "${TMPDIR:-/tmp}/remindctl-publish.XXXXXX")"
cleanup() {
  rm -rf "$work"
}
trap cleanup EXIT

run_gh() {
  env -u GH_TOKEN -u GITHUB_TOKEN -u HOMEBREW_GITHUB_API_TOKEN "$GH_BIN" "$@"
}

"$RELEASE_CHECK" "$TAG"
"$SOURCE_CHECK" "$TAG" "$work/local-source-proof.json"
env -u GH_TOKEN -u GITHUB_TOKEN -u HOMEBREW_GITHUB_API_TOKEN -u TRUSTED_WORKFLOW_SHA \
  GH_BIN="$GH_BIN" \
  "$DOWNLOAD_RELEASE" "$TAG" draft "$work/download"
if ! cmp -s "$work/local-source-proof.json" "$work/download/source-proof.json"; then
  echo "Draft source proof does not match the live local/remote signed-tag proof" >&2
  exit 1
fi
env -u GH_TOKEN -u GITHUB_TOKEN -u HOMEBREW_GITHUB_API_TOKEN \
  SOURCE_PROOF_FILE="$work/download/source-proof.json" \
  "$VERIFY_RELEASE" "$TAG" "$work/download/assets"

# This is intentionally the final read before the single publication mutation.
release_id="$(env -u GH_TOKEN -u GITHUB_TOKEN -u HOMEBREW_GITHUB_API_TOKEN \
  GH_BIN="$GH_BIN" \
  "$CHECK_METADATA" "$TAG" draft "$work/download/release-proof.json")"
if [[ ! "$release_id" =~ ^[1-9][0-9]*$ ]]; then
  echo "Invalid verified release id: $release_id" >&2
  exit 1
fi

run_gh api --method PATCH "repos/$RELEASE_REPOSITORY/releases/$release_id" \
  -F draft=false >"$work/published.json"
wait_seconds="$(python3 - \
  "$work/published.json" "$TAG" "$release_id" "$work/local-source-proof.json" \
  "$RELEASE_ARTIFACT" "$RELEASE_CHECKSUMS" "$RELEASE_INVENTORY" <<'PY'
import datetime
import json
import math
import sys

response_path, tag, release_id, source_proof_path, *expected_assets = sys.argv[1:]
with open(response_path, encoding="utf-8") as handle:
    response = json.load(handle)
with open(source_proof_path, encoding="utf-8") as handle:
    source = json.load(handle)
if response.get("id") != int(release_id):
    raise SystemExit("published release id changed")
if response.get("tag_name") != tag or response.get("target_commitish") != source["sourceCommit"]:
    raise SystemExit("published release source identity changed")
if response.get("draft") is not False or response.get("prerelease") is not False:
    raise SystemExit("release did not enter the exact published state")
assets = response.get("assets")
if not isinstance(assets, list):
    raise SystemExit("published release assets are malformed")
actual_assets = [asset.get("name") for asset in assets if isinstance(asset, dict)]
if sorted(actual_assets) != sorted(expected_assets) or len(actual_assets) != len(expected_assets):
    raise SystemExit(f"published release asset inventory changed: {actual_assets!r}")
timestamps = [("published_at", response.get("published_at")), ("release updated_at", response.get("updated_at"))]
timestamps.extend((f"asset {asset.get('name')} updated_at", asset.get("updated_at")) for asset in assets)
freshness_floor = None
for label, raw_value in timestamps:
    if not isinstance(raw_value, str):
        raise SystemExit(f"missing {label}")
    value = datetime.datetime.fromisoformat(raw_value.replace("Z", "+00:00"))
    freshness_floor = value if freshness_floor is None else max(freshness_floor, value)
now = datetime.datetime.now(datetime.timezone.utc)
delay = max(2, math.ceil((freshness_floor + datetime.timedelta(seconds=1) - now).total_seconds()))
if delay > 30:
    raise SystemExit("local clock is too far behind GitHub release timestamps")
print(delay)
PY
)"
if [[ ! "$wait_seconds" =~ ^[0-9]+$ ]]; then
  echo "Invalid published-verifier dispatch delay: $wait_seconds" >&2
  exit 1
fi
if ((wait_seconds > 0)); then
  sleep "$wait_seconds"
fi

run_gh workflow run release.yml \
  --repo "$RELEASE_REPOSITORY" \
  --ref "$RELEASE_DEFAULT_BRANCH" \
  -f "tag=$TAG" \
  -f draft=false

echo "Published the preverified draft and dispatched its protected published verifier for $TAG"
