# Manual tests

## Scope
Run on a local GUI session (not SSH-only) so the Reminders permission prompt can appear.

## Test data
- Use a dedicated list: `remindctl-manual-YYYYMMDD` (create if missing).
- Create 3 reminders with distinct states:
  - `remindctl test A` (due today, priority high)
  - `remindctl test B` (due tomorrow)
  - `remindctl test C` (no due date)

## Checklist
- authorize: `remindctl authorize`
- status: `remindctl status`
- doctor: `remindctl doctor --for-agent --json`
- list lists: `remindctl list`
- list table output: `remindctl list --format table`
- list list contents: `remindctl list "remindctl-manual-YYYYMMDD"`
- list by ID: `remindctl list --list-id <list-id-prefix>`
- add reminders (3 variants)
- add to exact list ID: `remindctl add "remindctl test D" --list-id <list-id-prefix>`
- show filters: `today`, `tomorrow`, `week`, `overdue`, `upcoming`, `open`, `completed`, `all`
- search: `remindctl search "remindctl test" --format table`
- info: `remindctl info <id-prefix> --json`
- export: `remindctl export --list-id <list-id-prefix> --json` and `--export-format csv`
- link: `remindctl link <id-prefix>` and `remindctl link --list-id <list-id-prefix>`
- open filter: `remindctl open --list-id <list-id-prefix> --format table`
- edit: update title/notes/priority/due date
- mixed alarms: create a reminder with absolute, relative, and location alarms; prove due-only and clear-due-only edits preserve all three, while explicit alarm replacement/clear changes only absolute alarms
- complete: mark one reminder complete
- delete: remove reminders, then delete list

## Release gate
- `make check` must pass strict SwiftLint, tests, and the 90% RemindCore coverage gate.
- `make docs-site` must build without broken internal links.
- `make release-harness` must prove missing/wrong signing, notarization, per-slice plist, source/tag, draft/runtime-token isolation, stale published-verifier proof, native verifier, publication, and Homebrew gates fail closed without partial output.
- `make release-check TAG=vX.Y.Z` must pass before pushing a release tag.
- Before draft creation, prove the inventory's source commit is the live remote default SHA and its exact verified signed tag object peels to that commit locally and remotely.
- Require both protected draft jobs: native Apple Silicon and native Intel, with exact per-slice signature/Info.plist proof and `REMINDCTL_VERSION` absent during execution.
- On the separately authorized clean macOS 26.5 VM, download and extract the draft through the normal browser path, confirm `com.apple.quarantine` propagated naturally to the binary, then run it and record that no Gatekeeper alert or block appears. Do not set the attribute manually and do not require raw-CLI `spctl` acceptance.
- In that VM, record whether Reminders permission is attributed to Terminal/Ghostty or the binary and test the prior-official-to-Foundation-signed upgrade. Do not infer TCC continuity from the preserved identifier.
- Publish only through `scripts/publish-release.sh`; require the exact protected published verifier and both native jobs before `scripts/update-homebrew.sh` can atomically apply the locally verified digest, install, test, and verify the formula.

## Results
- Date:
- Machine:
- Permission state before/after:
- Notes:
