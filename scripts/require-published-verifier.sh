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
pages="$(mktemp "${TMPDIR:-/tmp}/remindctl-published-releases.XXXXXX")"
runs="$(mktemp "${TMPDIR:-/tmp}/remindctl-published-runs.XXXXXX")"
jobs="$(mktemp "${TMPDIR:-/tmp}/remindctl-published-jobs.XXXXXX")"
selection="$(mktemp "${TMPDIR:-/tmp}/remindctl-published-selection.XXXXXX")"
cleanup() {
  rm -f "$pages" "$runs" "$jobs" "$selection"
}
trap cleanup EXIT

"$GH_BIN" api --paginate --slurp \
  "repos/$RELEASE_REPOSITORY/releases?per_page=100" >"$pages"
source_commit="$(python3 - "$pages" "$TAG" <<'PY'
import sys
import json

with open(sys.argv[1], encoding="utf-8") as handle:
    pages = json.load(handle)
releases = []
for page in pages:
    releases.extend(page if isinstance(page, list) else [page])
matches = [release for release in releases if release.get("tag_name") == sys.argv[2]]
if len(matches) != 1:
    raise SystemExit(f"expected exactly one published release; found {len(matches)}")
release = matches[0]
if release.get("draft") is not False or release.get("prerelease") is not False or not release.get("published_at"):
    raise SystemExit("release is not in the exact published state")
print(release.get("target_commitish", ""))
PY
)"
if [[ ! "$source_commit" =~ ^[0-9a-f]{40}$ ]]; then
  echo "Published release target is not an exact commit" >&2
  exit 1
fi

"$GH_BIN" api --paginate --slurp \
  "repos/$RELEASE_REPOSITORY/actions/workflows/release.yml/runs?event=workflow_dispatch&head_sha=$source_commit&per_page=100" \
  >"$runs"
python3 - \
  "$pages" "$runs" "$TAG" "$source_commit" "$selection" "$RELEASE_DEFAULT_BRANCH" \
  "$RELEASE_ARTIFACT" "$RELEASE_CHECKSUMS" "$RELEASE_INVENTORY" <<'PY'
import datetime
import json
import sys

pages_path, runs_path, tag, source_commit, output_path, default_branch, *expected_assets = sys.argv[1:]
with open(pages_path, encoding="utf-8") as handle:
    pages = json.load(handle)
with open(runs_path, encoding="utf-8") as handle:
    run_pages = json.load(handle)
releases = []
for page in pages:
    releases.extend(page if isinstance(page, list) else [page])
release = next(item for item in releases if item.get("tag_name") == tag)
published_at = datetime.datetime.fromisoformat(release["published_at"].replace("Z", "+00:00"))
assets = release.get("assets")
if not isinstance(assets, list):
    raise SystemExit("published release assets are malformed")
actual_assets = [asset.get("name") for asset in assets if isinstance(asset, dict)]
if sorted(actual_assets) != sorted(expected_assets) or len(actual_assets) != len(expected_assets):
    raise SystemExit(f"published release asset inventory changed: {actual_assets!r}")

freshness_values = [("published_at", release.get("published_at")), ("release updated_at", release.get("updated_at"))]
freshness_values.extend((f"asset {asset.get('name')} updated_at", asset.get("updated_at")) for asset in assets)
freshness_floor = published_at
for label, raw_value in freshness_values:
    if not isinstance(raw_value, str):
        raise SystemExit(f"missing {label}")
    value = datetime.datetime.fromisoformat(raw_value.replace("Z", "+00:00"))
    freshness_floor = max(freshness_floor, value)
runs = []
for page in run_pages:
    if isinstance(page, dict) and isinstance(page.get("workflow_runs"), list):
        runs.extend(page["workflow_runs"])
    elif isinstance(page, list):
        runs.extend(page)
    else:
        raise SystemExit("malformed workflow-run response")
candidates = []
expected_workflow_path = f".github/workflows/release.yml@{default_branch}"
for run in runs:
    started_raw = run.get("run_started_at")
    if not isinstance(started_raw, str):
        continue
    started = datetime.datetime.fromisoformat(started_raw.replace("Z", "+00:00"))
    if (
        run.get("event") == "workflow_dispatch"
        and run.get("head_sha") == source_commit
        and run.get("head_branch") == default_branch
        and run.get("path") == expected_workflow_path
        and run.get("display_title") == f"verify published {tag}"
        and run.get("status") == "completed"
        and run.get("conclusion") == "success"
        and started > freshness_floor
    ):
        candidates.append(run)
if not candidates:
    raise SystemExit("no exact successful published verifier run found")
run = max(candidates, key=lambda item: item.get("run_started_at") or item.get("created_at"))
if not isinstance(run.get("id"), int) or run["id"] <= 0:
    raise SystemExit("published verifier run has no valid id")
with open(output_path, "w", encoding="utf-8") as handle:
    json.dump({"id": run["id"], "url": run.get("html_url")}, handle)
PY

run_id="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["id"])' "$selection")"
"$GH_BIN" api --paginate --slurp \
  "repos/$RELEASE_REPOSITORY/actions/runs/$run_id/jobs?per_page=100" >"$jobs"
python3 - "$jobs" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    pages = json.load(handle)
jobs = []
for page in pages:
    if isinstance(page, dict) and isinstance(page.get("jobs"), list):
        jobs.extend(page["jobs"])
    elif isinstance(page, list):
        jobs.extend(page)
    else:
        raise SystemExit("malformed workflow-jobs response")
actual = {job.get("name"): job.get("conclusion") for job in jobs}
expected = {"native-arm64": "success", "native-x86_64": "success"}
if actual != expected:
    raise SystemExit(f"published verifier native job proof is incomplete: {actual!r}")
PY

run_url="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("url") or "")' "$selection")"
echo "Exact published verifier passed for $TAG: run $run_id $run_url"
