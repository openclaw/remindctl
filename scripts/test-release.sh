#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/release-config.sh
source "$ROOT/scripts/release-config.sh"
# shellcheck source=version.env
source "$ROOT/version.env"

TAG="v$MARKETING_VERSION"
draft_token_name="GH_TOKEN"
unset ACTIONS_RUNTIME_TOKEN ACTIONS_ID_TOKEN_REQUEST_TOKEN
source_commit="1111111111111111111111111111111111111111"
tag_object="2222222222222222222222222222222222222222"
work="$(mktemp -d "${TMPDIR:-/tmp}/remindctl-release-tests.XXXXXX")"
cleanup() {
  rm -rf "$work"
}
trap cleanup EXIT

fail() {
  echo "release harness failed: $*" >&2
  exit 1
}

expect_failure() {
  local label=$1
  shift
  if "$@" >"$work/failure.out" 2>&1; then
    fail "$label unexpectedly succeeded"
  fi
}

mkdir -p "$work/bin"

cat >"$work/bin/mock-lipo" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
echo "arm64 x86_64"
SH

cat >"$work/bin/mock-codesign" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
identity="${MOCK_IDENTITY:-Developer ID Application: OpenClaw Foundation (FWJYW4S8P8)}"
team="${MOCK_TEAM_ID:-FWJYW4S8P8}"
requirement_team="${MOCK_REQUIREMENT_TEAM:-FWJYW4S8P8}"
timestamp="${MOCK_TIMESTAMP:-Jul 9, 2026 at 12:00:00}"
if [[ " $* " == *" --check-notarization "* ]]; then
  [[ " $* " == *" -R=notarized "* ]] || exit 2
  if [[ "${MOCK_NOTARIZATION_MODE:-accepted}" == "missing" ]]; then
    echo "notarized requirement not satisfied" >&2
    exit 3
  fi
elif [[ " $* " == *" -dvvv "* ]]; then
  cat >&2 <<EOF
Identifier=com.steipete.remindctl
CodeDirectory v=20500 size=100 flags=0x10000(runtime) hashes=1+2 location=embedded
Authority=$identity
TeamIdentifier=$team
Timestamp=$timestamp
EOF
elif [[ " $* " == *" -d -r- "* ]]; then
  echo "designated => identifier \"com.steipete.remindctl\" and anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] /* exists */ and certificate leaf[field.1.2.840.113635.100.6.1.13] /* exists */ and certificate leaf[subject.OU] = $requirement_team" >&2
fi
SH

cat >"$work/bin/mock-otool" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
identifier="${MOCK_PLIST_IDENTIFIER:-com.steipete.remindctl}"
version="${MOCK_PLIST_VERSION:-${MOCK_VERSION:-0.3.3}}"
cat <<EOF
mock-remindctl:
(__TEXT,__info_plist) section
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key>
  <string>$identifier</string>
  <key>CFBundleShortVersionString</key>
  <string>$version</string>
  <key>CFBundleVersion</key>
  <string>$version</string>
</dict>
</plist>
EOF
SH

cat >"$work/remindctl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [[ -n "${EXECUTION_MARKER:-}" ]]; then
  touch "$EXECUTION_MARKER"
fi
if [[ -n "${REMINDCTL_VERSION:-}" ]]; then
  echo "$REMINDCTL_VERSION"
else
  echo "${MOCK_VERSION:-0.3.3}"
fi
SH

cat >"$work/bin/mock-build" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
cp "${MOCK_BUILD_SOURCE:?}" "$1"
chmod +x "$1"
SH

cat >"$work/bin/mock-xcrun" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${MOCK_NOTARY_STATUS:-Invalid}" == "Accepted" ]]; then
  echo '{"id":"00000000-0000-0000-0000-000000000001","status":"Accepted"}'
else
  echo '{"id":"00000000-0000-0000-0000-000000000001","status":"Invalid"}'
fi
SH

cat >"$work/bin/mock-source" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
cp "${MOCK_SOURCE_PROOF:?}" "$2"
if [[ -n "${MOCK_SOURCE_CHANGE_MARKER:-}" ]]; then
  if [[ -e "$MOCK_SOURCE_CHANGE_MARKER" ]]; then
    python3 - "$2" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    value = json.load(handle)
value["sourceCommit"] = "3333333333333333333333333333333333333333"
with open(sys.argv[1], "w", encoding="utf-8") as handle:
    json.dump(value, handle)
PY
  else
    touch "$MOCK_SOURCE_CHANGE_MARKER"
  fi
fi
SH

cat >"$work/bin/mock-download" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
mkdir -p "$3/assets"
cp "${MOCK_SOURCE_PROOF:?}" "$3/source-proof.json"
cp "${MOCK_RELEASE_PROOF:?}" "$3/release-proof.json"
if [[ -n "${MOCK_ASSET_DIR:-}" ]]; then
  cp "$MOCK_ASSET_DIR/remindctl-macos.zip" "$3/assets/remindctl-macos.zip"
  cp "$MOCK_ASSET_DIR/checksums.txt" "$3/assets/checksums.txt"
  cp "$MOCK_ASSET_DIR/release-inventory.json" "$3/assets/release-inventory.json"
  if [[ -n "${MOCK_DOWNLOAD_DRIFT_MARKER:-}" ]]; then
    if [[ -e "$MOCK_DOWNLOAD_DRIFT_MARKER" ]]; then
      printf 'changed' >>"$3/assets/remindctl-macos.zip"
    else
      touch "$MOCK_DOWNLOAD_DRIFT_MARKER"
    fi
  fi
fi
SH

cat >"$work/bin/mock-metadata" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${MOCK_METADATA_MODE:-valid}" == "invalid" ]]; then
  exit 4
fi
echo 123
SH

cat >"$work/bin/mock-brew" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$*" == "info --json=v2 steipete/tap/remindctl" ]]; then
  cat "${MOCK_BREW_INFO:?}"
  exit 0
fi
exit 2
SH

cat >"$work/bin/mock-gh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [[ -n "${GH_LOG:-}" ]]; then
  printf '%s\n' "$*" >>"$GH_LOG"
fi
if [[ "$*" == *"--method PATCH"* ]]; then
  printf '{"id":123,"tag_name":"%s","target_commitish":"%s","draft":false,"prerelease":false,"published_at":"2026-07-09T12:00:00Z","updated_at":"2026-07-09T12:00:00Z","assets":[{"name":"remindctl-macos.zip","updated_at":"2026-07-09T12:00:00Z"},{"name":"checksums.txt","updated_at":"2026-07-09T12:00:00Z"},{"name":"release-inventory.json","updated_at":"2026-07-09T12:00:00Z"}]}\n' \
    "${MOCK_TAG:-v0.3.3}" "${MOCK_SOURCE_COMMIT:?}"
  exit 0
fi
if [[ "$*" == *"contents/Formula/remindctl.rb?ref=main"* ]]; then
  python3 - "${MOCK_FORMULA_SOURCE:?}" <<'PY'
import base64
import json
import sys

with open(sys.argv[1], "rb") as handle:
    content = base64.b64encode(handle.read()).decode("ascii")
print(json.dumps({
    "type": "file",
    "path": "Formula/remindctl.rb",
    "sha": "4444444444444444444444444444444444444444",
    "encoding": "base64",
    "content": content,
}))
PY
  exit 0
fi
if [[ "$*" == *"actions/workflows/release.yml/runs"* ]]; then
  workflow_path=".github/workflows/release.yml@main"
  if [[ "${GH_MODE:-valid}" == "bare-workflow-path" ]]; then
    workflow_path=".github/workflows/release.yml"
  fi
  printf '[{"workflow_runs":[{"id":456,"event":"workflow_dispatch","head_branch":"main","head_sha":"%s","path":"%s","display_title":"verify published %s","status":"completed","conclusion":"success","run_started_at":"2026-07-09T12:01:00Z","html_url":"https://example.invalid/run/456"}]}]\n' \
    "${MOCK_SOURCE_COMMIT:?}" "$workflow_path" "${MOCK_TAG:-v0.3.3}"
  exit 0
fi
if [[ "$*" == *"actions/runs/456/jobs"* ]]; then
  if [[ "${GH_MODE:-valid}" == "missing-intel" ]]; then
    echo '[{"jobs":[{"name":"native-arm64","conclusion":"success"}]}]'
  else
    echo '[{"jobs":[{"name":"native-arm64","conclusion":"success"},{"name":"native-x86_64","conclusion":"success"}]}]'
  fi
  exit 0
fi
if [[ "$*" == *"releases?per_page=100"* ]]; then
  tag="${MOCK_TAG:-v0.3.3}"
  if [[ "${GH_MODE:-valid}" == "malformed" ]]; then
    printf '[[{"tag_name":"%s","draft":true,"prerelease":false,"assets":[{"name":"unexpected.zip","id":1,"size":1}]}]]\n' "$tag"
  else
    python3 - "$tag" "${MOCK_VERSION:-0.3.3}" "${MOCK_RELEASE_BODY_FILE:?}" \
      "${MOCK_ASSET_DIR:?}" "${MOCK_SOURCE_COMMIT:?}" <<'PY'
import json
import os
import sys

tag, version, body_path, asset_dir, source_commit = sys.argv[1:]
with open(body_path, encoding="utf-8") as handle:
    body = handle.read()
names = ["remindctl-macos.zip", "checksums.txt", "release-inventory.json"]
published = os.environ.get("MOCK_RELEASE_STATE") == "published"
mode = os.environ.get("GH_MODE", "valid")
title = f"remindctl {version}" if mode != "wrong-title" else "wrong title"
body = body if mode != "wrong-body" else body + "changed\n"
target = source_commit if mode != "wrong-target" else "3333333333333333333333333333333333333333"
assets = [
    {
        "name": name,
        "id": index,
        "size": os.path.getsize(os.path.join(asset_dir, name)),
        "digest": None,
        "updated_at": (
            "2026-07-09T12:02:00Z" if mode == "stale-assets"
            else "2026-07-09T12:01:00Z" if mode == "equal-freshness"
            else "2026-07-09T12:00:00Z"
        ),
    }
    for index, name in enumerate(names, start=1)
]
print(json.dumps([[{
    "id": 123,
    "tag_name": tag,
    "name": title,
    "body": body,
    "target_commitish": target,
    "draft": not published,
    "prerelease": False,
    "updated_at": "2026-07-09T12:00:00Z",
    "published_at": "2026-07-09T12:00:00Z" if published else None,
    "assets": assets,
}]]))
PY
  fi
  exit 0
fi
case "$*" in
  *releases/assets/1*) cat "${MOCK_ASSET_DIR:?}/remindctl-macos.zip" ;;
  *releases/assets/2*)
    if [[ "${GH_MODE:-valid}" == "partial" ]]; then
      exit 4
    fi
    cat "${MOCK_ASSET_DIR:?}/checksums.txt"
    ;;
  *releases/assets/3*) cat "${MOCK_ASSET_DIR:?}/release-inventory.json" ;;
  *git/ref/heads/main*)
    source_commit="${MOCK_SOURCE_COMMIT:?}"
    if [[ "${GH_MODE:-valid}" == "wrong-default" ]]; then
      source_commit=3333333333333333333333333333333333333333
    fi
    printf '{"ref":"refs/heads/main","object":{"type":"commit","sha":"%s","url":"mock"}}\n' \
      "$source_commit"
    ;;
  *git/ref/tags/*)
    tag_object="${MOCK_TAG_OBJECT:?}"
    if [[ "${GH_MODE:-valid}" == "wrong-tag" ]]; then
      tag_object=3333333333333333333333333333333333333333
    fi
    printf '{"ref":"refs/tags/%s","object":{"type":"tag","sha":"%s","url":"mock"}}\n' \
      "${MOCK_TAG:-v0.3.3}" "$tag_object"
    ;;
  *git/tags/*)
    verified=true
    reason=valid
    if [[ "${GH_MODE:-valid}" == "invalid-signature" ]]; then
      verified=false
      reason=bad_signature
    fi
    printf '{"tag":"%s","object":{"type":"commit","sha":"%s"},"verification":{"verified":%s,"reason":"%s"}}\n' \
      "${MOCK_TAG:-v0.3.3}" "${MOCK_SOURCE_COMMIT:?}" "$verified" "$reason"
    ;;
  *repos/openclaw/remindctl)
    echo '{"full_name":"openclaw/remindctl","default_branch":"main"}'
    ;;
  *) echo '[]' ;;
esac
SH

chmod +x "$work/bin/"* "$work/remindctl"
export OTOOL_BIN="$work/bin/mock-otool"

echo "==> release verifier mock success"
env -u GH_TOKEN -u GITHUB_TOKEN -u HOMEBREW_GITHUB_API_TOKEN \
  MOCK_VERSION="$MARKETING_VERSION" \
  CODESIGN_BIN="$work/bin/mock-codesign" \
  LIPO_BIN="$work/bin/mock-lipo" \
  "$ROOT/scripts/verify-macos-binary.sh" "$work/remindctl" "$MARKETING_VERSION" >/dev/null

echo "==> wrong signing identity is rejected"
expect_failure "wrong signing identity" env \
  -u GH_TOKEN -u GITHUB_TOKEN -u HOMEBREW_GITHUB_API_TOKEN \
  MOCK_IDENTITY='Developer ID Application: Personal (WRONGTEAM)' \
  MOCK_TEAM_ID=WRONGTEAM MOCK_VERSION="$MARKETING_VERSION" \
  CODESIGN_BIN="$work/bin/mock-codesign" \
  LIPO_BIN="$work/bin/mock-lipo" \
  "$ROOT/scripts/verify-macos-binary.sh" "$work/remindctl" "$MARKETING_VERSION"

echo "==> wrong embedded designated requirement is rejected"
expect_failure "wrong designated requirement" env \
  -u GH_TOKEN -u GITHUB_TOKEN -u HOMEBREW_GITHUB_API_TOKEN \
  MOCK_REQUIREMENT_TEAM=WRONGTEAM MOCK_VERSION="$MARKETING_VERSION" \
  CODESIGN_BIN="$work/bin/mock-codesign" \
  LIPO_BIN="$work/bin/mock-lipo" \
  "$ROOT/scripts/verify-macos-binary.sh" "$work/remindctl" "$MARKETING_VERSION"

echo "==> missing secure timestamp is rejected"
expect_failure "missing secure timestamp" env \
  -u GH_TOKEN -u GITHUB_TOKEN -u HOMEBREW_GITHUB_API_TOKEN \
  MOCK_TIMESTAMP=none MOCK_VERSION="$MARKETING_VERSION" \
  CODESIGN_BIN="$work/bin/mock-codesign" \
  LIPO_BIN="$work/bin/mock-lipo" \
  "$ROOT/scripts/verify-macos-binary.sh" "$work/remindctl" "$MARKETING_VERSION"

echo "==> missing online notarization constraint is rejected"
expect_failure "missing online notarization constraint" env \
  -u GH_TOKEN -u GITHUB_TOKEN -u HOMEBREW_GITHUB_API_TOKEN \
  MOCK_NOTARIZATION_MODE=missing MOCK_VERSION="$MARKETING_VERSION" \
  CODESIGN_BIN="$work/bin/mock-codesign" \
  LIPO_BIN="$work/bin/mock-lipo" \
  "$ROOT/scripts/verify-macos-binary.sh" "$work/remindctl" "$MARKETING_VERSION"

echo "==> wrong per-architecture embedded plist is rejected"
expect_failure "wrong embedded plist" env \
  -u GH_TOKEN -u GITHUB_TOKEN -u HOMEBREW_GITHUB_API_TOKEN \
  MOCK_PLIST_VERSION=0.3.2 MOCK_VERSION="$MARKETING_VERSION" \
  CODESIGN_BIN="$work/bin/mock-codesign" \
  LIPO_BIN="$work/bin/mock-lipo" \
  OTOOL_BIN="$work/bin/mock-otool" \
  "$ROOT/scripts/verify-macos-binary.sh" "$work/remindctl" "$MARKETING_VERSION"

echo "==> REMINDCTL_VERSION cannot spoof a stale binary"
expect_failure "version environment spoof" env \
  -u GH_TOKEN -u GITHUB_TOKEN -u HOMEBREW_GITHUB_API_TOKEN \
  REMINDCTL_VERSION="$MARKETING_VERSION" MOCK_VERSION=0.3.2 \
  CODESIGN_BIN="$work/bin/mock-codesign" \
  LIPO_BIN="$work/bin/mock-lipo" \
  OTOOL_BIN="$work/bin/mock-otool" \
  "$ROOT/scripts/verify-macos-binary.sh" "$work/remindctl" "$MARKETING_VERSION"

echo "==> candidate execution refuses draft token"
execution_marker="$work/executed"
expect_failure "draft token execution" env \
  "$draft_token_name=placeholder" EXECUTION_MARKER="$execution_marker" \
  MOCK_VERSION="$MARKETING_VERSION" \
  CODESIGN_BIN="$work/bin/mock-codesign" \
  LIPO_BIN="$work/bin/mock-lipo" \
  "$ROOT/scripts/verify-macos-binary.sh" "$work/remindctl" "$MARKETING_VERSION"
[[ ! -e "$execution_marker" ]] || fail "candidate executed with GH_TOKEN present"

echo "==> candidate execution refuses Actions runtime token"
expect_failure "Actions runtime token execution" env \
  -u GH_TOKEN -u GITHUB_TOKEN -u HOMEBREW_GITHUB_API_TOKEN \
  ACTIONS_RUNTIME_TOKEN=placeholder EXECUTION_MARKER="$execution_marker" \
  MOCK_VERSION="$MARKETING_VERSION" \
  CODESIGN_BIN="$work/bin/mock-codesign" \
  LIPO_BIN="$work/bin/mock-lipo" \
  "$ROOT/scripts/verify-macos-binary.sh" "$work/remindctl" "$MARKETING_VERSION"
[[ ! -e "$execution_marker" ]] || fail "candidate executed with ACTIONS_RUNTIME_TOKEN present"

echo "==> exact artifact manifest is enforced"
assets="$work/assets"
payload="$work/payload"
mkdir -p "$assets" "$payload"
cp "$work/remindctl" "$payload/remindctl"
(
  cd "$payload"
  /usr/bin/ditto --norsrc -c -k remindctl "$assets/$RELEASE_ARTIFACT"
)
sha="$(shasum -a 256 "$assets/$RELEASE_ARTIFACT" | awk '{print $1}')"
size="$(stat -f '%z' "$assets/$RELEASE_ARTIFACT")"
printf '%s  %s\n' "$sha" "$RELEASE_ARTIFACT" >"$assets/$RELEASE_CHECKSUMS"
python3 - \
  "$assets/$RELEASE_INVENTORY" "$TAG" "$MARKETING_VERSION" "$sha" "$size" \
  "$source_commit" "$tag_object" <<'PY'
import json
import sys

path, tag, version, sha256, size, source_commit, tag_object = sys.argv[1:]
with open(path, "w", encoding="utf-8") as handle:
    json.dump(
        {
            "schemaVersion": 1,
            "tag": tag,
            "tagObject": tag_object,
            "sourceCommit": source_commit,
            "version": version,
            "repository": "openclaw/remindctl",
            "identifier": "com.steipete.remindctl",
            "teamIdentifier": "FWJYW4S8P8",
            "architectures": ["arm64", "x86_64"],
            "assets": [{"name": "remindctl-macos.zip", "sha256": sha256, "size": int(size)}],
        },
        handle,
    )
PY
python3 - "$work/source-proof.json" "$TAG" "$source_commit" "$tag_object" <<'PY'
import json
import sys

path, tag, source_commit, tag_object = sys.argv[1:]
with open(path, "w", encoding="utf-8") as handle:
    json.dump(
        {
            "schemaVersion": 1,
            "repository": "openclaw/remindctl",
            "defaultBranch": "main",
            "tag": tag,
            "tagObject": tag_object,
            "sourceCommit": source_commit,
            "signedTagVerified": True,
        },
        handle,
    )
PY
env -u GH_TOKEN -u GITHUB_TOKEN -u HOMEBREW_GITHUB_API_TOKEN \
  SOURCE_PROOF_FILE="$work/source-proof.json" \
  MOCK_VERSION="$MARKETING_VERSION" \
  CODESIGN_BIN="$work/bin/mock-codesign" \
  LIPO_BIN="$work/bin/mock-lipo" \
  "$ROOT/scripts/verify-macos-release.sh" "$TAG" "$assets" >/dev/null
printf '{}\n' >"$assets/$RELEASE_INVENTORY"
expect_failure "malformed release inventory" env \
  -u GH_TOKEN -u GITHUB_TOKEN -u HOMEBREW_GITHUB_API_TOKEN \
  SOURCE_PROOF_FILE="$work/source-proof.json" \
  CODESIGN_BIN="$work/bin/mock-codesign" \
  LIPO_BIN="$work/bin/mock-lipo" \
  "$ROOT/scripts/verify-macos-release.sh" "$TAG" "$assets"

echo "==> downloader rejects malformed and partial inventories atomically"
mock_api_assets="$work/mock-api-assets"
mock_release_notes="$work/mock-release-notes.md"
mkdir -p "$mock_api_assets"
printf 'artifact\n' >"$mock_api_assets/$RELEASE_ARTIFACT"
printf 'checksum\n' >"$mock_api_assets/$RELEASE_CHECKSUMS"
python3 - "$mock_api_assets/$RELEASE_INVENTORY" "$source_commit" "$tag_object" <<'PY'
import json
import sys

path, source_commit, tag_object = sys.argv[1:]
with open(path, "w", encoding="utf-8") as handle:
    json.dump({"sourceCommit": source_commit, "tagObject": tag_object}, handle)
PY
"$ROOT/scripts/extract-release-notes.sh" "$MARKETING_VERSION" "$mock_release_notes"
env \
  "$draft_token_name=placeholder" GH_BIN="$work/bin/mock-gh" \
  MOCK_TAG="$TAG" MOCK_VERSION="$MARKETING_VERSION" \
  MOCK_RELEASE_BODY_FILE="$mock_release_notes" MOCK_ASSET_DIR="$mock_api_assets" \
  MOCK_SOURCE_COMMIT="$source_commit" MOCK_TAG_OBJECT="$tag_object" \
  "$ROOT/scripts/download-release-assets.sh" "$TAG" draft "$work/download-valid" >/dev/null
[[ -f "$work/download-valid/source-proof.json" ]] || fail "valid download omitted source proof"
[[ -d "$work/download-valid/assets" ]] || fail "valid download omitted asset directory"
metadata_id="$(env \
  GH_BIN="$work/bin/mock-gh" MOCK_TAG="$TAG" MOCK_VERSION="$MARKETING_VERSION" \
  MOCK_RELEASE_BODY_FILE="$mock_release_notes" MOCK_ASSET_DIR="$mock_api_assets" \
  MOCK_SOURCE_COMMIT="$source_commit" MOCK_TAG_OBJECT="$tag_object" \
  "$ROOT/scripts/check-release-metadata.sh" "$TAG" draft "$work/download-valid/release-proof.json")"
[[ "$metadata_id" == "123" ]] || fail "exact release metadata did not revalidate"
for metadata_mode in wrong-title wrong-body wrong-target; do
  expect_failure "$metadata_mode release metadata" env \
    "$draft_token_name=placeholder" GH_MODE="$metadata_mode" GH_BIN="$work/bin/mock-gh" \
    MOCK_TAG="$TAG" MOCK_VERSION="$MARKETING_VERSION" \
    MOCK_RELEASE_BODY_FILE="$mock_release_notes" MOCK_ASSET_DIR="$mock_api_assets" \
    MOCK_SOURCE_COMMIT="$source_commit" MOCK_TAG_OBJECT="$tag_object" \
    "$ROOT/scripts/download-release-assets.sh" "$TAG" draft "$work/download-$metadata_mode"
  [[ ! -e "$work/download-$metadata_mode" ]] || fail "$metadata_mode left output behind"
done
expect_failure "malformed API inventory" env \
  "$draft_token_name=placeholder" GH_MODE=malformed GH_BIN="$work/bin/mock-gh" \
  MOCK_TAG="$TAG" MOCK_VERSION="$MARKETING_VERSION" \
  MOCK_RELEASE_BODY_FILE="$mock_release_notes" MOCK_ASSET_DIR="$mock_api_assets" \
  MOCK_SOURCE_COMMIT="$source_commit" MOCK_TAG_OBJECT="$tag_object" \
  "$ROOT/scripts/download-release-assets.sh" "$TAG" draft "$work/download-malformed"
[[ ! -e "$work/download-malformed" ]] || fail "malformed download left output behind"
expect_failure "partial API download" env \
  "$draft_token_name=placeholder" GH_MODE=partial GH_BIN="$work/bin/mock-gh" \
  MOCK_TAG="$TAG" MOCK_VERSION="$MARKETING_VERSION" \
  MOCK_RELEASE_BODY_FILE="$mock_release_notes" MOCK_ASSET_DIR="$mock_api_assets" \
  MOCK_SOURCE_COMMIT="$source_commit" MOCK_TAG_OBJECT="$tag_object" \
  "$ROOT/scripts/download-release-assets.sh" "$TAG" draft "$work/download-partial"
[[ ! -e "$work/download-partial" ]] || fail "partial download left output behind"
expect_failure "wrong live default ref" env \
  "$draft_token_name=placeholder" GH_MODE=wrong-default GH_BIN="$work/bin/mock-gh" \
  MOCK_TAG="$TAG" MOCK_VERSION="$MARKETING_VERSION" \
  MOCK_RELEASE_BODY_FILE="$mock_release_notes" MOCK_ASSET_DIR="$mock_api_assets" \
  MOCK_SOURCE_COMMIT="$source_commit" MOCK_TAG_OBJECT="$tag_object" \
  "$ROOT/scripts/download-release-assets.sh" "$TAG" draft "$work/download-wrong-default"
[[ ! -e "$work/download-wrong-default" ]] || fail "wrong default ref left output behind"
expect_failure "wrong remote tag object" env \
  "$draft_token_name=placeholder" GH_MODE=wrong-tag GH_BIN="$work/bin/mock-gh" \
  MOCK_TAG="$TAG" MOCK_VERSION="$MARKETING_VERSION" \
  MOCK_RELEASE_BODY_FILE="$mock_release_notes" MOCK_ASSET_DIR="$mock_api_assets" \
  MOCK_SOURCE_COMMIT="$source_commit" MOCK_TAG_OBJECT="$tag_object" \
  "$ROOT/scripts/download-release-assets.sh" "$TAG" draft "$work/download-wrong-tag"
[[ ! -e "$work/download-wrong-tag" ]] || fail "wrong tag ref left output behind"
expect_failure "unverified signed tag" env \
  "$draft_token_name=placeholder" GH_MODE=invalid-signature GH_BIN="$work/bin/mock-gh" \
  MOCK_TAG="$TAG" MOCK_VERSION="$MARKETING_VERSION" \
  MOCK_RELEASE_BODY_FILE="$mock_release_notes" MOCK_ASSET_DIR="$mock_api_assets" \
  MOCK_SOURCE_COMMIT="$source_commit" MOCK_TAG_OBJECT="$tag_object" \
  "$ROOT/scripts/download-release-assets.sh" "$TAG" draft "$work/download-invalid-signature"
[[ ! -e "$work/download-invalid-signature" ]] || fail "unverified tag left output behind"

echo "==> published verifier requires both native architecture jobs"
env \
  GH_BIN="$work/bin/mock-gh" MOCK_RELEASE_STATE=published \
  MOCK_TAG="$TAG" MOCK_VERSION="$MARKETING_VERSION" \
  MOCK_RELEASE_BODY_FILE="$mock_release_notes" MOCK_ASSET_DIR="$mock_api_assets" \
  MOCK_SOURCE_COMMIT="$source_commit" MOCK_TAG_OBJECT="$tag_object" \
  "$ROOT/scripts/require-published-verifier.sh" "$TAG" >/dev/null
expect_failure "missing native Intel verifier" env \
  GH_BIN="$work/bin/mock-gh" GH_MODE=missing-intel MOCK_RELEASE_STATE=published \
  MOCK_TAG="$TAG" MOCK_VERSION="$MARKETING_VERSION" \
  MOCK_RELEASE_BODY_FILE="$mock_release_notes" MOCK_ASSET_DIR="$mock_api_assets" \
  MOCK_SOURCE_COMMIT="$source_commit" MOCK_TAG_OBJECT="$tag_object" \
  "$ROOT/scripts/require-published-verifier.sh" "$TAG"
expect_failure "unqualified published verifier workflow path" env \
  GH_BIN="$work/bin/mock-gh" GH_MODE=bare-workflow-path MOCK_RELEASE_STATE=published \
  MOCK_TAG="$TAG" MOCK_VERSION="$MARKETING_VERSION" \
  MOCK_RELEASE_BODY_FILE="$mock_release_notes" MOCK_ASSET_DIR="$mock_api_assets" \
  MOCK_SOURCE_COMMIT="$source_commit" MOCK_TAG_OBJECT="$tag_object" \
  "$ROOT/scripts/require-published-verifier.sh" "$TAG"
expect_failure "stale published verifier after asset replacement" env \
  GH_BIN="$work/bin/mock-gh" GH_MODE=stale-assets MOCK_RELEASE_STATE=published \
  MOCK_TAG="$TAG" MOCK_VERSION="$MARKETING_VERSION" \
  MOCK_RELEASE_BODY_FILE="$mock_release_notes" MOCK_ASSET_DIR="$mock_api_assets" \
  MOCK_SOURCE_COMMIT="$source_commit" MOCK_TAG_OBJECT="$tag_object" \
  "$ROOT/scripts/require-published-verifier.sh" "$TAG"
expect_failure "published verifier equal to asset timestamp" env \
  GH_BIN="$work/bin/mock-gh" GH_MODE=equal-freshness MOCK_RELEASE_STATE=published \
  MOCK_TAG="$TAG" MOCK_VERSION="$MARKETING_VERSION" \
  MOCK_RELEASE_BODY_FILE="$mock_release_notes" MOCK_ASSET_DIR="$mock_api_assets" \
  MOCK_SOURCE_COMMIT="$source_commit" MOCK_TAG_OBJECT="$tag_object" \
  "$ROOT/scripts/require-published-verifier.sh" "$TAG"

echo "==> publish helper mutates only after exact local proof"
publish_log="$work/publish-gh.log"
env \
  RELEASE_CHECK=/usr/bin/true SOURCE_CHECK="$work/bin/mock-source" \
  DOWNLOAD_RELEASE="$work/bin/mock-download" VERIFY_RELEASE=/usr/bin/true \
  CHECK_METADATA="$work/bin/mock-metadata" GH_BIN="$work/bin/mock-gh" GH_LOG="$publish_log" \
  MOCK_SOURCE_PROOF="$work/source-proof.json" \
  MOCK_RELEASE_PROOF="$work/download-valid/release-proof.json" \
  MOCK_TAG="$TAG" MOCK_SOURCE_COMMIT="$source_commit" \
  "$ROOT/scripts/publish-release.sh" "$TAG" >/dev/null
[[ "$(grep -c -- '--method PATCH' "$publish_log")" == "1" ]] || fail "publish helper did not issue one exact mutation"
[[ "$(grep -c -- 'workflow run release.yml' "$publish_log")" == "1" ]] || fail "publish helper did not dispatch one published verifier"
grep -Fq 'delay = max(2,' "$ROOT/scripts/publish-release.sh"
failed_publish_log="$work/failed-publish-gh.log"
expect_failure "publish metadata changed" env \
  RELEASE_CHECK=/usr/bin/true SOURCE_CHECK="$work/bin/mock-source" \
  DOWNLOAD_RELEASE="$work/bin/mock-download" VERIFY_RELEASE=/usr/bin/true \
  CHECK_METADATA="$work/bin/mock-metadata" GH_BIN="$work/bin/mock-gh" GH_LOG="$failed_publish_log" \
  MOCK_METADATA_MODE=invalid MOCK_SOURCE_PROOF="$work/source-proof.json" \
  MOCK_RELEASE_PROOF="$work/download-valid/release-proof.json" \
  MOCK_TAG="$TAG" MOCK_SOURCE_COMMIT="$source_commit" \
  "$ROOT/scripts/publish-release.sh" "$TAG"
[[ ! -e "$failed_publish_log" ]] || fail "publish helper contacted GitHub after failed final metadata proof"

echo "==> Homebrew mutation requires published artifact and verifier proof"
homebrew_log="$work/homebrew-gh.log"
expect_failure "Homebrew preflight" env \
  DOWNLOAD_RELEASE=/usr/bin/false GH_BIN="$work/bin/mock-gh" GH_LOG="$homebrew_log" \
  "$ROOT/scripts/update-homebrew.sh" "$TAG"
[[ ! -e "$homebrew_log" ]] || fail "Homebrew workflow was contacted before published proof"

echo "==> Homebrew formula metadata is bound to the canonical release"
formula_source="$work/remindctl-current.rb"
formula_candidate="$work/remindctl-candidate.rb"
cat >"$formula_source" <<'RUBY'
class Remindctl < Formula
  desc "Fast CLI for Apple Reminders"
  homepage "https://github.com/steipete/remindctl"
  url "https://github.com/steipete/remindctl/releases/download/v0.3.2/remindctl-macos.zip"
  sha256 "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
  license "MIT"

  def install
    bin.install "remindctl"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/remindctl --version")
  end
end
RUBY
expected_formula_sha="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
"$ROOT/scripts/render-homebrew-formula.sh" \
  "$formula_source" "$formula_candidate" "$TAG" "$expected_formula_sha" >/dev/null
grep -Fxq '  homepage "https://github.com/openclaw/remindctl"' "$formula_candidate"
grep -Fxq "  url \"https://github.com/openclaw/remindctl/releases/download/$TAG/remindctl-macos.zip\"" \
  "$formula_candidate"
grep -Fxq "  sha256 \"$expected_formula_sha\"" "$formula_candidate"
expect_failure "invalid digest-bound formula" \
  "$ROOT/scripts/render-homebrew-formula.sh" \
  "$formula_source" "$work/remindctl-invalid.rb" "$TAG" invalid
[[ ! -e "$work/remindctl-invalid.rb" ]] || fail "invalid formula render left output behind"

homebrew_drift_log="$work/homebrew-drift-gh.log"
expect_failure "Homebrew asset changed before mutation" env \
  DOWNLOAD_RELEASE="$work/bin/mock-download" VERIFY_RELEASE=/usr/bin/true \
  CHECK_METADATA=/usr/bin/true REQUIRE_VERIFIER=/usr/bin/true \
  GH_BIN="$work/bin/mock-gh" GH_LOG="$homebrew_drift_log" \
  MOCK_SOURCE_PROOF="$work/source-proof.json" \
  MOCK_RELEASE_PROOF="$work/download-valid/release-proof.json" \
  MOCK_ASSET_DIR="$mock_api_assets" MOCK_FORMULA_SOURCE="$formula_source" \
  MOCK_DOWNLOAD_DRIFT_MARKER="$work/homebrew-drift-marker" \
  BREW_BIN=/usr/bin/false \
  "$ROOT/scripts/update-homebrew.sh" "$TAG"
if ! grep -Fq 'Published release asset changed before the Homebrew update' "$work/failure.out"; then
  sed -n '1,20p' "$work/failure.out" >&2
  fail "Homebrew drift regression failed before the intended pre-mutation comparison"
fi
if [[ -e "$homebrew_drift_log" ]] && grep -Fq -- '--method PUT' "$homebrew_drift_log"; then
  fail "Homebrew formula was mutated after release asset drift"
fi

formula_assets="$work/formula-assets"
formula_info="$work/formula-info.json"
mkdir -p "$formula_assets"
python3 - "$formula_assets/$RELEASE_INVENTORY" "$formula_info" "$TAG" "$MARKETING_VERSION" <<'PY'
import json
import sys

inventory_path, info_path, tag, version = sys.argv[1:]
sha256 = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
with open(inventory_path, "w", encoding="utf-8") as handle:
    json.dump({"assets": [{"name": "remindctl-macos.zip", "sha256": sha256, "size": 1}]}, handle)
formula = {
    "formulae": [{
        "full_name": "steipete/tap/remindctl",
        "tap": "steipete/tap",
        "homepage": "https://github.com/openclaw/remindctl",
        "versions": {"stable": version},
        "urls": {"stable": {
            "url": f"https://github.com/openclaw/remindctl/releases/download/{tag}/remindctl-macos.zip",
            "checksum": sha256,
        }},
    }],
    "casks": [],
}
with open(info_path, "w", encoding="utf-8") as handle:
    json.dump(formula, handle)
PY
env BREW_BIN="$work/bin/mock-brew" MOCK_BREW_INFO="$formula_info" \
  "$ROOT/scripts/verify-homebrew-formula.sh" "$TAG" "$formula_assets" >/dev/null
python3 - "$formula_info" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    value = json.load(handle)
value["formulae"][0]["homepage"] = "https://github.com/steipete/remindctl"
with open(sys.argv[1], "w", encoding="utf-8") as handle:
    json.dump(value, handle)
PY
expect_failure "noncanonical Homebrew formula" env \
  BREW_BIN="$work/bin/mock-brew" MOCK_BREW_INFO="$formula_info" \
  "$ROOT/scripts/verify-homebrew-formula.sh" "$TAG" "$formula_assets"

echo "==> official packager fails closed before output mutation"
env \
  NOTARYTOOL_PROFILE=test MOCK_NOTARY_STATUS=Accepted \
  MOCK_BUILD_SOURCE="$work/remindctl" BUILD_SCRIPT="$work/bin/mock-build" \
  CODESIGN_BIN="$work/bin/mock-codesign" XCRUN_BIN="$work/bin/mock-xcrun" \
  CHECK_ARTIFACT=/usr/bin/true SOURCE_PREFLIGHT="$work/bin/mock-source" \
  MOCK_SOURCE_PROOF="$work/source-proof.json" \
  VERIFY_RELEASE=/usr/bin/true VERIFY_ATTEMPTS=1 \
  OUTPUT_DIR="$work/package-success" \
  "$ROOT/scripts/package-macos-release.sh" "$TAG" >/dev/null
python3 - \
  "$work/package-success" "$RELEASE_ARTIFACT" "$RELEASE_CHECKSUMS" "$RELEASE_INVENTORY" <<'PY'
import os
import sys

root, *expected = sys.argv[1:]
actual = sorted(os.listdir(root))
if actual != sorted(expected):
    raise SystemExit(f"official package output contains unexpected files: {actual!r}")
PY
expect_failure "missing runtime notary profile" env \
  -u NOTARYTOOL_PROFILE \
  OUTPUT_DIR="$work/package-missing-profile" \
  "$ROOT/scripts/package-macos-release.sh" "$TAG"
[[ ! -e "$work/package-missing-profile" ]] || fail "missing profile left release output behind"
expect_failure "wrong package identity" env \
  NOTARYTOOL_PROFILE=test CODESIGN_IDENTITY='Developer ID Application: Personal (WRONGTEAM)' \
  OUTPUT_DIR="$work/package-wrong-identity" \
  "$ROOT/scripts/package-macos-release.sh" "$TAG"
[[ ! -e "$work/package-wrong-identity" ]] || fail "wrong identity left release output behind"
expect_failure "rejected notarization" env \
  NOTARYTOOL_PROFILE=test MOCK_NOTARY_STATUS=Invalid \
  MOCK_BUILD_SOURCE="$work/remindctl" BUILD_SCRIPT="$work/bin/mock-build" \
  CODESIGN_BIN="$work/bin/mock-codesign" XCRUN_BIN="$work/bin/mock-xcrun" \
  CHECK_ARTIFACT=/usr/bin/true SOURCE_PREFLIGHT="$work/bin/mock-source" \
  MOCK_SOURCE_PROOF="$work/source-proof.json" VERIFY_ATTEMPTS=1 \
  OUTPUT_DIR="$work/package-notary-rejected" \
  "$ROOT/scripts/package-macos-release.sh" "$TAG"
[[ ! -e "$work/package-notary-rejected" ]] || fail "notary failure left release output behind"
expect_failure "post-notary verifier failure" env \
  NOTARYTOOL_PROFILE=test MOCK_NOTARY_STATUS=Accepted \
  MOCK_BUILD_SOURCE="$work/remindctl" BUILD_SCRIPT="$work/bin/mock-build" \
  CODESIGN_BIN="$work/bin/mock-codesign" XCRUN_BIN="$work/bin/mock-xcrun" \
  CHECK_ARTIFACT=/usr/bin/true SOURCE_PREFLIGHT="$work/bin/mock-source" \
  MOCK_SOURCE_PROOF="$work/source-proof.json" \
  VERIFY_RELEASE=/usr/bin/false VERIFY_ATTEMPTS=1 \
  OUTPUT_DIR="$work/package-verify-rejected" \
  "$ROOT/scripts/package-macos-release.sh" "$TAG"
[[ ! -e "$work/package-verify-rejected" ]] || fail "verification failure left release output behind"
expect_failure "source changed during packaging" env \
  NOTARYTOOL_PROFILE=test MOCK_NOTARY_STATUS=Accepted \
  MOCK_BUILD_SOURCE="$work/remindctl" BUILD_SCRIPT="$work/bin/mock-build" \
  CODESIGN_BIN="$work/bin/mock-codesign" XCRUN_BIN="$work/bin/mock-xcrun" \
  CHECK_ARTIFACT=/usr/bin/true SOURCE_PREFLIGHT="$work/bin/mock-source" \
  MOCK_SOURCE_PROOF="$work/source-proof.json" \
  MOCK_SOURCE_CHANGE_MARKER="$work/source-change-marker" \
  VERIFY_RELEASE=/usr/bin/true VERIFY_ATTEMPTS=1 \
  OUTPUT_DIR="$work/package-source-changed" \
  "$ROOT/scripts/package-macos-release.sh" "$TAG"
[[ ! -e "$work/package-source-changed" ]] || fail "source change left release output behind"

echo "==> draft creation performs all local proof before GitHub mutation"
gh_log="$work/gh.log"
expect_failure "draft preflight" env \
  RELEASE_CHECK_BIN=/usr/bin/true RELEASE_VERIFY_BIN=/usr/bin/false \
  GH_BIN="$work/bin/mock-gh" GH_LOG="$gh_log" \
  "$ROOT/scripts/create-release-draft.sh" "$TAG"
[[ ! -e "$gh_log" ]] || fail "GitHub was contacted before local artifact proof passed"

echo "==> protected verifier trust boundary is pinned"
workflow="$ROOT/.github/workflows/release.yml"
# shellcheck disable=SC2016 # Match the literal GitHub expression.
grep -Fq 'ref: ${{ github.workflow_sha }}' "$workflow"
grep -Fq 'persist-credentials: false' "$workflow"
grep -Fq 'github.event.repository.default_branch' "$workflow"
grep -Fq 'github.workflow_ref' "$workflow"
grep -Fq 'macos-15-intel' "$workflow"
grep -Fq 'EXPECTED_HOST_ARCH' "$workflow"
grep -Fq 'TRUSTED_WORKFLOW_SHA' "$workflow"
grep -Fq 'source-proof.json' "$workflow"
grep -Fq 'env -u GH_TOKEN -u GITHUB_TOKEN -u HOMEBREW_GITHUB_API_TOKEN' "$workflow"
grep -Fq -- '-u ACTIONS_RUNTIME_TOKEN -u ACTIONS_ID_TOKEN_REQUEST_TOKEN' "$workflow"
if grep -Eq 'softprops/action-gh-release|gh release (create|edit|upload)|update-homebrew|tags:|^  release:' "$workflow"; then
  fail "CI release workflow contains a publication path"
fi
grep -Fq -- '--draft' "$ROOT/scripts/create-release-draft.sh"
# shellcheck disable=SC2016 # Match the literal shell variable in the helper.
grep -Fq -- '--target "$head_commit"' "$ROOT/scripts/create-release-draft.sh"
if grep -Eq 'release edit|--draft=false|update-homebrew' "$ROOT/scripts/create-release-draft.sh"; then
  fail "draft helper contains publication or Homebrew mutation"
fi

echo "==> standalone CLI verifier uses the notarized codesign constraint"
binary_verifier="$ROOT/scripts/verify-macos-binary.sh"
grep -Fq -- '--check-notarization' "$binary_verifier"
grep -Fq -- '-R=notarized' "$binary_verifier"
# shellcheck disable=SC2016 # Match the literal per-architecture verification loop.
grep -Fq -- '--arch "$architecture"' "$binary_verifier"
grep -Fq -- 'env -u REMINDCTL_VERSION' "$binary_verifier"
grep -Fq 'ACTIONS_RUNTIME_TOKEN ACTIONS_ID_TOKEN_REQUEST_TOKEN' "$binary_verifier"
if grep -Eq 'SPCTL_BIN|spctl|syspolicy|stapler|xattr' "$binary_verifier"; then
  fail "standalone CLI verifier contains an app-bundle assessment or simulated-quarantine path"
fi

echo "==> Homebrew mutation consumes the locally verified artifact digest"
homebrew_updater="$ROOT/scripts/update-homebrew.sh"
# shellcheck disable=SC2016 # Match literal shell code in the updater.
grep -Fq 'artifact_sha="$(shasum -a 256' "$homebrew_updater"
# shellcheck disable=SC2016 # Match literal shell code in the updater.
grep -Fq '"$RENDER_FORMULA" "$current_formula" "$candidate_formula" "$TAG" "$artifact_sha"' \
  "$homebrew_updater"
# shellcheck disable=SC2016 # Match literal shell code in the updater.
grep -Fq -- '--method PUT "repos/$TAP_REPO/contents/$TAP_FORMULA"' "$homebrew_updater"
# shellcheck disable=SC2016 # Match literal shell code in the updater.
grep -Fq 'cmp -s "$work/verified/assets/$asset" "$work/precommit/assets/$asset"' \
  "$homebrew_updater"
if grep -Fq 'workflow run' "$homebrew_updater"; then
  fail "Homebrew updater delegates digest selection to an unbound remote workflow"
fi

echo "==> runtime release credential locators stay untracked"
grep -Fxq '.mac-release.env' "$ROOT/.gitignore"
if grep -Eq 'MAC_RELEASE_CODESIGN_(OP_ITEM|KEYCHAIN_PATH)=|NOTARYTOOL_PROFILE=' \
  "$ROOT/.mac-release.env.example"; then
  fail "sanitized release example contains a runtime credential locator"
fi

echo "Release harness passed"
