#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

CACHE_PATH="${HOME}/Library/Caches/remindctl/swiftpm"
COVERAGE_BUILD_PATH="${ROOT_DIR}/.build/coverage"
mkdir -p "${CACHE_PATH}"

MIN_COVERAGE="${COVERAGE_MIN:-90}"
INCLUDE_REGEX="${COVERAGE_INCLUDE_REGEX:-/Sources/RemindCore/}"
EXCLUDE_REGEX="${COVERAGE_EXCLUDE_REGEX:-/Sources/RemindCore/EventKitStore.swift}"

echo "==> swift test --enable-code-coverage (isolated build dir)"
swift test --enable-code-coverage --build-path "${COVERAGE_BUILD_PATH}" --cache-path "${CACHE_PATH}" >/dev/null

REPORT_JSON="$(
  find "${COVERAGE_BUILD_PATH}" -type f -path "*/codecov/remindctl.json" -print0 2>/dev/null \
    | xargs -0 ls -t 2>/dev/null \
    | head -n 1
)"

if [ -z "${REPORT_JSON}" ] || [ ! -f "${REPORT_JSON}" ]; then
  echo "ERROR: Coverage report not found (expected .build/**/codecov/remindctl.json)." >&2
  exit 1
fi

python3 - "$REPORT_JSON" "$INCLUDE_REGEX" "$EXCLUDE_REGEX" "$MIN_COVERAGE" <<'PY'
import json
import os
import re
import sys

report_path, include_re, exclude_re, min_str = sys.argv[1:5]
min_coverage = float(min_str)

with open(report_path, "r", encoding="utf-8") as f:
    obj = json.load(f)

files = obj["data"][0]["files"]

include = re.compile(include_re)
exclude = re.compile(exclude_re) if exclude_re else None

selected = []
for item in files:
    filename = item["filename"]
    if not include.search(filename):
        continue
    if exclude and exclude.search(filename):
        continue
    summary = item.get("summary", {}).get("lines", {})
    count = int(summary.get("count", 0))
    covered = int(summary.get("covered", 0))
    selected.append((filename, covered, count))

if not selected:
    print(f"ERROR: No files matched coverage include regex: {include_re}", file=sys.stderr)
    print(f"       exclude regex: {exclude_re or '(none)'}", file=sys.stderr)
    sys.exit(1)

total_lines = sum(count for _, _, count in selected)
total_covered = sum(covered for _, covered, _ in selected)
percent = (total_covered / total_lines * 100.0) if total_lines else 0.0

repo_root = os.getcwd() + os.sep

def rel(path: str) -> str:
    return path[len(repo_root):] if path.startswith(repo_root) else path

print(f"==> Coverage (lines): {percent:.1f}% ({total_covered}/{total_lines})")
print(f"    Scope: include={include_re} exclude={exclude_re or '(none)'}")
print(f"    Min: {min_coverage:.1f}%")

worst = sorted(selected, key=lambda t: (t[1] / t[2] if t[2] else 0.0, -t[2]))[:10]
print("    Lowest covered files:")
for filename, covered, count in worst:
    p = (covered / count * 100.0) if count else 0.0
    print(f"    - {p:5.1f}%  {covered:4d}/{count:4d}  {rel(filename)}")

if percent + 1e-9 < min_coverage:
    sys.exit(2)
PY
