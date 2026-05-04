#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <release-tag>" >&2
  exit 1
fi

TAG="$1"
TAP_REPO="steipete/homebrew-tap"
WORKFLOW="update-formula.yml"
SAFE_TAG=$(printf '%s' "$TAG" | tr -c 'A-Za-z0-9._-' '-')
REQUEST_ID="remindctl-${SAFE_TAG}-$(date -u +%Y%m%dT%H%M%SZ)-$$"

gh workflow run "$WORKFLOW" \
  --repo "$TAP_REPO" \
  --ref main \
  -f formula=remindctl \
  -f tag="$TAG" \
  -f repository=steipete/remindctl \
  -f macos_artifact="remindctl-macos.zip" \
  -f request_id="$REQUEST_ID"

echo "Homebrew tap update dispatched: $REQUEST_ID"

RUN_ID=""
for _ in {1..30}; do
  RUN_ID=$(gh run list \
    --repo "$TAP_REPO" \
    --workflow "$WORKFLOW" \
    --branch main \
    --limit 20 \
    --json databaseId,displayTitle \
    --jq ".[] | select(.displayTitle | contains(\"($REQUEST_ID)\")) | .databaseId" \
    | head -n 1)

  if [[ -n "$RUN_ID" ]]; then
    break
  fi

  sleep 2
done

if [[ -z "$RUN_ID" ]]; then
  echo "Timed out waiting for Homebrew tap workflow run: $REQUEST_ID" >&2
  echo "Monitor: https://github.com/$TAP_REPO/actions/workflows/$WORKFLOW" >&2
  exit 1
fi

gh run watch "$RUN_ID" --repo "$TAP_REPO" --exit-status
