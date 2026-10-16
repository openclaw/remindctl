#!/usr/bin/env bash
# Exercise the workflow's real lipo argument order on universal and thin Mach-O objects.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
printf 'int release_fixture;\n' > "$work/fixture.c"
for architecture in arm64 x86_64; do
  clang -target "$architecture-apple-macos14" -c "$work/fixture.c" -o "$work/$architecture.o"
done
lipo -create "$work/arm64.o" "$work/x86_64.o" -output "$work/universal.o"
gate="$(sed -n '/^[ ]*for architecture in arm64 x86_64; do lipo /p' "$ROOT/.github/workflows/release.yml")"
[[ -n "$gate" ]] || { echo 'Workflow architecture gate is missing' >&2; exit 1; }
verify_fixture() {
  local command
  command=${gate//payload\/remindctl/"$1"}
  bash -euc "$command"
}
verify_fixture "$work/universal.o"
if verify_fixture "$work/arm64.o" 2>/dev/null; then
  echo 'Architecture gate accepted a thin Mach-O' >&2
  exit 1
fi
echo 'Workflow architecture gate accepts universal and rejects thin Mach-O'
