# Changelog

## 0.3.6 - 2026-09-07

**Highlights:** Clearer alarm guidance and a repaired Homebrew release handoff.

- Clarify in `add`/`edit` help and command docs that `--alarm` schedules a notification without enabling Apple's native Urgent toggle; use Reminders.app to enable Urgent. Thanks @Amitdvl.
- Unblock Homebrew updates by accepting GitHub's bare release-verifier workflow path while retaining exact branch, source commit, freshness, and native-architecture checks.

## 0.3.5 - 2026-09-05

**Highlights:** Repeated list creation now preserves existing lists, reminder reads and writes handle missing calendars, and week views respect calendar boundaries.

- Make `list --create` reuse a unique existing list instead of inserting another calendar with the same title, and report its current reminder counts in JSON. Thanks @SebTardif.
- Return a calendar-missing error from add, edit, and complete instead of trapping when EventKit leaves a reminder without a calendar after save. Thanks @SebTardif.
- Exclude reminders due at the start of next week from `week` and `show week` listings. Thanks @SebTardif.
- Skip fetched reminders with a missing calendar so orphaned rows cannot crash reminder reads. Thanks @SebTardif.
- Bound `doctor` rich-read sqlite3 probes to 30 seconds so a stuck local database query fails with a timeout instead of hanging the CLI. Thanks @SebTardif.
- Update the docs workflow to Node.js 26 and `actions/setup-node@v7`, and verify the docs build in pull-request CI.
- Keep release-policy tests runnable while release notes are still `Unreleased`, without relaxing the finalized-notes requirement for real releases.

## 0.3.4 - 2026-08-09

**Highlight:** the CLI can no longer hang forever on an unresponsive system
service.

- Bound EventKit reminder fetches and Core Location geocoding to 30 seconds so stalled system callbacks fail with a clear error instead of hanging the CLI indefinitely. Both paths share one timeout contract, and cancellation now propagates to the underlying EventKit fetch or geocoder rather than leaving it running; thanks @SebTardif and @vincentkoc.

## 0.3.3 - 2026-07-09
- Keep every alarm unchanged for due-only edits, and preserve relative and location alarms when `edit --alarm` or `edit --clear-alarm` replaces or clears absolute alarms.
- Ship official macOS archives as universal hardened-runtime binaries signed by OpenClaw Foundation, notarized locally, verified with the standalone-binary notarization constraint, and Gatekeeper-tested through naturally quarantined clean-VM execution before publication.
- Bind release assets to the live protected commit and exact verified signed tag, require native Apple Silicon and Intel verification, and fail closed across draft publication and Homebrew handoff.

## 0.3.2 - 2026-07-01
- Make `--url` visible in Reminders.app by retaining the EventKit URL and mirroring one managed notes link; `--clear-url` removes only that link; thanks @TurboTheTurtle.
- Build the release archive as a universal arm64/x86_64 macOS binary and verify both slices before publishing; thanks @TurboTheTurtle.
- Update GitHub Actions workflows to `actions/checkout@v7` for current dependency and fork-checkout security fixes.

## 0.3.1 - 2026-06-11
- Add support for setting the reminder URL field via `--url` on `add`/`edit` and `--clear-url` on `edit`; thanks @jeremylahners.
- Redesign the GitHub Pages documentation site with light/dark mode and a reminder-focused overview.

## 0.3.0 - 2026-05-28
- Add exact `--list-id` targeting, normalized list-name resolution, `doctor`, `export`, `link`, `open`, shell completion generation, table output, and release preflight checks.
- Add a GitHub Pages documentation site for remindctl.sh.
- Raise the RemindCore coverage gate to 90% and run SwiftLint in strict mode.
- Add `search` and `info` commands for title, notes, URL lookup, and detailed reminder inspection.
- Resolve numeric edit/complete/delete indexes against the default `show` view instead of unrelated completed reminders.
- Add a release helper for Homebrew tap updates; thanks @dinakars777.

## 0.2.0 - 2026-05-04
- Add location-based reminder triggers via `--location`, `--leaving`, and `--radius`
- Add simple recurrence support via `--repeat` and `--no-repeat`
- Add EventKit alarm support via `--alarm` and `--clear-alarm`
- Add reminder `url` to JSON output when EventKit exposes one
- Add `lastModifiedDate` to reminder JSON output
- Add `creationDate` to reminder JSON output
- Add `open` filter for all incomplete reminders
- Accept local ISO 8601 due dates without a timezone suffix
- Preserve date-only due inputs as all-day reminders instead of midnight reminders
- Allow `list` to show reminders from multiple list names in one command

## 0.1.1 - 2026-01-11
- Fix Swift 6 strict concurrency crash when fetching reminders

## 0.1.0 - 2026-01-03
- Reminders CLI with Commander-based command router
- Show reminders with filters (today/tomorrow/week/overdue/upcoming/completed/all/date)
- Manage lists (list, create, rename, delete)
- Add, edit, complete, and delete reminders
- Authorization status and permission prompt command
- JSON and plain output modes for scripting
- Flexible date parsing (relative, ISO 8601, and common formats)
- GitHub Actions CI with lint, tests, and coverage gate
