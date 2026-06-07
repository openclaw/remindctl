# Changelog

## 0.3.1 - Unreleased
- Add support for setting the reminder URL field via `--url` on `add`/`edit` and `--clear-url` on `edit` (EKReminder.url; previously exposed read-only in JSON output).
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
