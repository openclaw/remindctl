#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <vX.Y.Z> <release-asset-directory>" >&2
  exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/release-config.sh
source "$ROOT/scripts/release-config.sh"

TAG="$1"
VERSION="${TAG#v}"
ASSET_DIR="$2"
BREW_BIN=${BREW_BIN:-brew}
info="$(mktemp "${TMPDIR:-/tmp}/remindctl-brew-info.XXXXXX")"
cleanup() {
  rm -f "$info"
}
trap cleanup EXIT
HOMEBREW_NO_AUTO_UPDATE=1 "$BREW_BIN" info --json=v2 steipete/tap/remindctl >"$info"

python3 - \
  "$info" "$ASSET_DIR/$RELEASE_INVENTORY" "$TAG" "$VERSION" "$RELEASE_REPOSITORY" \
  "$RELEASE_ARTIFACT" <<'PY'
import json
import sys

info_path, inventory_path, tag, version, repository, artifact = sys.argv[1:]
with open(info_path, encoding="utf-8") as handle:
    info = json.load(handle)
with open(inventory_path, encoding="utf-8") as handle:
    inventory = json.load(handle)
formulae = info.get("formulae")
if not isinstance(formulae, list) or len(formulae) != 1:
    raise SystemExit("expected exactly one Homebrew formula")
formula = formulae[0]
expected_url = f"https://github.com/{repository}/releases/download/{tag}/{artifact}"
stable = formula.get("urls", {}).get("stable", {})
expected_sha = inventory.get("assets", [{}])[0].get("sha256")
if formula.get("full_name") != "steipete/tap/remindctl" or formula.get("tap") != "steipete/tap":
    raise SystemExit("Homebrew install route changed")
if formula.get("homepage") != f"https://github.com/{repository}":
    raise SystemExit("Homebrew homepage is not canonical")
if formula.get("versions", {}).get("stable") != version:
    raise SystemExit("Homebrew formula version does not match the release")
if stable.get("url") != expected_url or stable.get("checksum") != expected_sha:
    raise SystemExit("Homebrew formula URL or checksum does not match the exact release artifact")
PY

echo "Verified exact Homebrew formula metadata for $TAG"
