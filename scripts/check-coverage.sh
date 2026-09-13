#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

CACHE_PATH="${HOME}/Library/Caches/remindctl/swiftpm"
COVERAGE_BUILD_PATH="${ROOT_DIR}/.build/coverage"
mkdir -p "${CACHE_PATH}"

MIN_COVERAGE="${COVERAGE_MIN:-90}"
INCLUDE_REGEX="${COVERAGE_INCLUDE_REGEX:-/Sources/RemindCore/}"
EXCLUDE_REGEX="${COVERAGE_EXCLUDE_REGEX:-/Sources/RemindCore/(EventKitStore|EventKitLocation|SystemOperationCancellation)\\.swift}"

scripts/generate-version.sh
python3 scripts/test-coverage.py

echo "==> swift test --enable-code-coverage (isolated build dir)"
swift test --enable-code-coverage --build-path "${COVERAGE_BUILD_PATH}" --cache-path "${CACHE_PATH}" >/dev/null

REPORT_JSON="$(swift test --build-path "${COVERAGE_BUILD_PATH}" --show-codecov-path)"

if [ -z "${REPORT_JSON}" ] || [ ! -f "${REPORT_JSON}" ]; then
  echo "ERROR: Coverage report not found (expected .build/**/codecov/remindctl.json)." >&2
  exit 1
fi

python3 "$ROOT_DIR/scripts/report-coverage.py" "$REPORT_JSON" "$INCLUDE_REGEX" "$EXCLUDE_REGEX" "$MIN_COVERAGE"
