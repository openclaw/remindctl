#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 4 ]]; then
  echo "Usage: $0 <current-formula.rb> <output-formula.rb> <vX.Y.Z> <artifact-sha256>" >&2
  exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/release-config.sh
source "$ROOT/scripts/release-config.sh"

INPUT="$1"
OUTPUT="$2"
TAG="$3"
SHA256="$4"

if [[ ! -f "$INPUT" || -L "$INPUT" ]]; then
  echo "Expected a regular current formula: $INPUT" >&2
  exit 1
fi
if [[ -e "$OUTPUT" ]]; then
  echo "Refusing to replace formula output: $OUTPUT" >&2
  exit 1
fi
if [[ ! "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ || ! "$SHA256" =~ ^[0-9a-f]{64}$ ]]; then
  echo "Invalid release tag or artifact SHA-256" >&2
  exit 1
fi

parent="$(dirname "$OUTPUT")"
mkdir -p "$parent"
temp="$(mktemp "$parent/.remindctl-formula.XXXXXX")"
cleanup() {
  rm -f "$temp"
}
trap cleanup EXIT

python3 - "$INPUT" "$temp" "$TAG" "$SHA256" "$RELEASE_REPOSITORY" "$RELEASE_ARTIFACT" <<'PY'
import re
import sys

input_path, output_path, tag, sha256, repository, artifact = sys.argv[1:]
with open(input_path, encoding="utf-8") as handle:
    content = handle.read()

required_fragments = [
    "class Remindctl < Formula",
    'bin.install "remindctl"',
    'shell_output("#{bin}/remindctl --version")',
]
for fragment in required_fragments:
    if content.count(fragment) != 1:
        raise SystemExit(f"unexpected remindctl formula structure: {fragment!r}")

replacements = [
    (r'^  homepage "[^"]+"$', f'  homepage "https://github.com/{repository}"'),
    (
        r'^  url "[^"]+"$',
        f'  url "https://github.com/{repository}/releases/download/{tag}/{artifact}"',
    ),
    (r'^  sha256 "[0-9a-f]{64}"$', f'  sha256 "{sha256}"'),
]
for pattern, replacement in replacements:
    content, count = re.subn(pattern, replacement, content, flags=re.MULTILINE)
    if count != 1:
        raise SystemExit(f"unexpected formula field count for {pattern!r}: {count}")
if "github.com/steipete/remindctl" in content:
    raise SystemExit("formula still contains the non-canonical source repository")

with open(output_path, "w", encoding="utf-8") as handle:
    handle.write(content)
PY

mv "$temp" "$OUTPUT"
trap - EXIT
echo "Rendered digest-bound Homebrew formula for $TAG"
