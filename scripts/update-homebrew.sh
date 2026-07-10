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
TAP_REPO="steipete/homebrew-tap"
TAP_BRANCH="main"
TAP_FORMULA="Formula/remindctl.rb"
GH_BIN=${GH_BIN:-gh}
BREW_BIN=${BREW_BIN:-brew}
DOWNLOAD_RELEASE=${DOWNLOAD_RELEASE:-"$ROOT/scripts/download-release-assets.sh"}
VERIFY_RELEASE=${VERIFY_RELEASE:-"$ROOT/scripts/verify-macos-release.sh"}
CHECK_METADATA=${CHECK_METADATA:-"$ROOT/scripts/check-release-metadata.sh"}
REQUIRE_VERIFIER=${REQUIRE_VERIFIER:-"$ROOT/scripts/require-published-verifier.sh"}
RENDER_FORMULA=${RENDER_FORMULA:-"$ROOT/scripts/render-homebrew-formula.sh"}
VERIFY_FORMULA=${VERIFY_FORMULA:-"$ROOT/scripts/verify-homebrew-formula.sh"}
VERIFY_INSTALL=${VERIFY_INSTALL:-"$ROOT/scripts/verify-homebrew-install.sh"}
work="$(mktemp -d "${TMPDIR:-/tmp}/remindctl-homebrew.XXXXXX")"
cleanup() {
  rm -rf "$work"
}
trap cleanup EXIT

run_gh() {
  env -u GH_TOKEN -u GITHUB_TOKEN -u HOMEBREW_GITHUB_API_TOKEN "$GH_BIN" "$@"
}

verify_published_release() {
  local output=$1
  env -u GH_TOKEN -u GITHUB_TOKEN -u HOMEBREW_GITHUB_API_TOKEN -u TRUSTED_WORKFLOW_SHA \
    GH_BIN="$GH_BIN" \
    "$DOWNLOAD_RELEASE" "$TAG" published "$output"
  env -u GH_TOKEN -u GITHUB_TOKEN -u HOMEBREW_GITHUB_API_TOKEN \
    SOURCE_PROOF_FILE="$output/source-proof.json" \
    "$VERIFY_RELEASE" "$TAG" "$output/assets"
  env -u GH_TOKEN -u GITHUB_TOKEN -u HOMEBREW_GITHUB_API_TOKEN \
    GH_BIN="$GH_BIN" \
    "$CHECK_METADATA" "$TAG" published "$output/release-proof.json" >/dev/null
  env -u GH_TOKEN -u GITHUB_TOKEN -u HOMEBREW_GITHUB_API_TOKEN \
    GH_BIN="$GH_BIN" \
    "$REQUIRE_VERIFIER" "$TAG" >/dev/null
}

verify_published_release "$work/verified"
artifact_sha="$(shasum -a 256 "$work/verified/assets/$RELEASE_ARTIFACT" | awk '{print $1}')"

formula_response="$work/formula-response.json"
current_formula="$work/current-remindctl.rb"
candidate_formula="$work/candidate-remindctl.rb"
run_gh api "repos/$TAP_REPO/contents/$TAP_FORMULA?ref=$TAP_BRANCH" >"$formula_response"
formula_blob_sha="$(python3 - "$formula_response" "$current_formula" "$TAP_FORMULA" <<'PY'
import base64
import binascii
import json
import re
import sys

response_path, output_path, expected_path = sys.argv[1:]
with open(response_path, encoding="utf-8") as handle:
    value = json.load(handle)
sha = value.get("sha")
content = value.get("content")
if value.get("type") != "file" or value.get("path") != expected_path:
    raise SystemExit("unexpected tap formula response")
if not isinstance(sha, str) or re.fullmatch(r"[0-9a-f]{40}", sha) is None:
    raise SystemExit("tap formula has no exact blob SHA")
if value.get("encoding") != "base64" or not isinstance(content, str):
    raise SystemExit("tap formula content encoding changed")
try:
    decoded = base64.b64decode("".join(content.split()), validate=True)
    decoded.decode("utf-8")
except (binascii.Error, UnicodeDecodeError) as error:
    raise SystemExit("tap formula content is malformed") from error
with open(output_path, "wb") as handle:
    handle.write(decoded)
print(sha)
PY
)"

"$RENDER_FORMULA" "$current_formula" "$candidate_formula" "$TAG" "$artifact_sha" >/dev/null

# Repeat every release/verifier proof immediately before the sole tap mutation.
verify_published_release "$work/precommit"
for proof in source-proof.json release-proof.json; do
  if ! cmp -s "$work/verified/$proof" "$work/precommit/$proof"; then
    echo "Published release metadata changed before the Homebrew update" >&2
    exit 1
  fi
done
for asset in "$RELEASE_ARTIFACT" "$RELEASE_CHECKSUMS" "$RELEASE_INVENTORY"; do
  if ! cmp -s "$work/verified/assets/$asset" "$work/precommit/assets/$asset"; then
    echo "Published release asset changed before the Homebrew update: $asset" >&2
    exit 1
  fi
done

if ! cmp -s "$current_formula" "$candidate_formula"; then
  payload="$work/formula-update.json"
  python3 - "$candidate_formula" "$formula_blob_sha" "$TAG" "$TAP_BRANCH" "$payload" <<'PY'
import base64
import json
import sys

formula_path, blob_sha, tag, branch, output_path = sys.argv[1:]
with open(formula_path, "rb") as handle:
    content = base64.b64encode(handle.read()).decode("ascii")
value = {
    "message": f"remindctl: update formula for {tag}",
    "content": content,
    "sha": blob_sha,
    "branch": branch,
}
with open(output_path, "w", encoding="utf-8") as handle:
    json.dump(value, handle)
PY
  run_gh api --method PUT "repos/$TAP_REPO/contents/$TAP_FORMULA" \
    --input "$payload" >"$work/formula-update-response.json"
  python3 - "$work/formula-update-response.json" "$candidate_formula" "$TAP_FORMULA" <<'PY'
import hashlib
import json
import re
import sys

response_path, formula_path, expected_path = sys.argv[1:]
with open(response_path, encoding="utf-8") as handle:
    response = json.load(handle)
with open(formula_path, "rb") as handle:
    content = handle.read()
expected_blob = hashlib.sha1(f"blob {len(content)}\0".encode() + content).hexdigest()
actual = response.get("content", {})
commit = response.get("commit", {})
if actual.get("path") != expected_path or actual.get("sha") != expected_blob:
    raise SystemExit("tap update response does not identify the digest-bound formula")
if not isinstance(commit.get("sha"), str) or re.fullmatch(r"[0-9a-f]{40}", commit["sha"]) is None:
    raise SystemExit("tap update response has no exact commit")
PY
fi

"$BREW_BIN" update
BREW_BIN="$BREW_BIN" "$VERIFY_FORMULA" "$TAG" "$work/verified/assets"
if "$BREW_BIN" list --versions remindctl >/dev/null 2>&1; then
  "$BREW_BIN" upgrade steipete/tap/remindctl
else
  "$BREW_BIN" install steipete/tap/remindctl
fi
"$BREW_BIN" test steipete/tap/remindctl
BREW_BIN="$BREW_BIN" "$VERIFY_INSTALL" "$TAG"
echo "Verified digest-bound Homebrew formula and installed binary for $TAG"
