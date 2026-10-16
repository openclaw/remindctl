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
- `make release-harness` must prove signature, notarization, per-slice plist, source/tag and token-isolation checks with credential-free fixtures.
- `make release-check TAG=vX.Y.Z` must pass before pushing an authorized release tag.
- Run the default no-publish dispatch on protected main; require exact-source push CI, signing/notarization, and native arm64/Intel verification to pass.
- On a disposable macOS GUI session, download and extract the candidate through the normal browser path, confirm `com.apple.quarantine` propagated naturally, then record Gatekeeper behavior. Do not set the attribute manually or substitute raw-CLI `spctl` acceptance.
- Record whether Reminders permission belongs to Terminal/Ghostty or the binary, and test upgrade from the previous official binary. Do not infer TCC continuity from the identifier alone.
- Only the tag-triggered CI pipeline publishes releases and dispatches Homebrew. Verify its exact tap run and the installed version after a real authorized release.

## Results
- Date:
- Machine:
- Permission state before/after:
- Notes:
