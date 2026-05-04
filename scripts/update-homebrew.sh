#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <release-tag>" >&2
  exit 1
fi

TAG="$1"

gh workflow run update-formula.yml \
  --repo steipete/homebrew-tap \
  --ref main \
  -f formula=remindctl \
  -f tag="$TAG" \
  -f repository=steipete/remindctl \
  -f macos_artifact="remindctl-macos.zip"

echo "Homebrew tap update dispatched. Monitor: https://github.com/steipete/homebrew-tap/actions"
