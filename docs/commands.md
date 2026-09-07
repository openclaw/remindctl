---
title: Commands
description: "Common remindctl commands and options."
---

# Commands

## Show reminders

```bash
remindctl today
remindctl tomorrow
remindctl week
remindctl overdue
remindctl upcoming
remindctl open
remindctl completed
remindctl all
remindctl 2026-01-03
```

`week` and `show week` include incomplete reminders due within the current calendar week, including its start but excluding the opening midnight of the next week.

Limit a view to one list:

```bash
remindctl show overdue --list Work
remindctl show overdue --list-id 7A12
```

Show multiple lists together:

```bash
remindctl list Work Errands
```

## Create reminders

```bash
remindctl add "Review notes"
remindctl add "Call Sam" --list Work --due tomorrow
remindctl add "Call Sam" --list-id 7A12 --due tomorrow
remindctl add "Take vitamins" --due tomorrow --repeat daily
remindctl add "Check mailbox" --location "1 Apple Park Way, Cupertino, CA"
```

Useful `add` options:

- `--list <name>` chooses the target list.
- `--list-id <id-prefix>` chooses the target list exactly.
- `--due <date>` sets a due date.
- `--alarm <date>` sets a notification alarm.
- `--notes <text>` adds notes.
- `--repeat <rule>` sets simple recurrence.
- `--priority <none|low|medium|high>` sets priority.
- `--url <url>` stores the EventKit URL and mirrors it into notes as `remindctl URL (managed): ...` so Reminders.app shows the link.
- `--location <address>` creates an arriving geofence trigger.
- `--leaving` changes a location trigger to leaving.
- `--radius <meters>` adjusts the geofence radius.

`--alarm` schedules a notification; it does not enable the native **Urgent** toggle in Reminders.app. EventKit does not expose Urgent, so `remindctl` cannot set it. Use `--alarm` for a notification, or enable Urgent directly in Reminders.app.

## Edit reminders

```bash
remindctl edit 1 --title "New title"
remindctl edit 4A83 --due "2026-01-04 09:00"
remindctl edit 4A83 --clear-due
remindctl edit 4A83 --list Office
remindctl edit 4A83 --list-id 7A12
remindctl edit 4A83 --no-repeat
```

`edit`, `complete`, and `delete` accept indexes from the current default listing or ID prefixes.

If `add`, `edit`, or `complete` reports `Reminder is missing a calendar`, EventKit saved the reminder but returned it without its list. Check Reminders.app before retrying; this error does not roll back the saved change.

Changing or clearing only the due date leaves every alarm unchanged. Explicit alarm edits preserve relative and location-based alarms while replacing or clearing absolute alarms.
As with `add`, `edit --alarm` schedules a notification without enabling native Urgent. Set Urgent in Reminders.app.

## Lists

```bash
remindctl list
remindctl list Work
remindctl list Projects --create
remindctl list Work --rename Office
remindctl list OldList --delete --force
remindctl list --list-id 7A12
remindctl list --list-id 7A12 --rename Archive
```

Mutating list operations accept one list name. Read-only list views can accept multiple names.
`list <name> --create` creates a missing list or reuses a unique matching list. Repeating it preserves the list and its reminders; `--json` reports the current incomplete and overdue counts. An ambiguous name fails instead of creating another list.
List names resolve by exact match, case-insensitive match, then a normalized match that ignores emoji and punctuation.
If a name is ambiguous, use `--list-id`.

## Search and inspect

```bash
remindctl search "invoice" --list Work
remindctl search "project" --completed --json
remindctl info 1
remindctl info 4A83 --json
```

## Export, links, and app handoff

```bash
remindctl export --json
remindctl export --list Work --export-format csv
remindctl link 1
remindctl link --list-id 7A12
remindctl open 1
remindctl open --list Work
remindctl open --list Work --app
remindctl completion zsh
```

`open --list Work` keeps the historical open-reminders filter. Add `--app` to open that list in Reminders.app.

## Diagnostics

```bash
remindctl status
remindctl doctor --for-agent
```

## Output

```bash
remindctl all --json
remindctl list --json
remindctl today --plain
remindctl today --format table
remindctl status --json
```

Global output flags:

- `--json` emits machine-readable JSON.
- `--plain` emits stable tab-separated lines.
- `--format table` emits tabular output.
- `--quiet` emits minimal output.
- `--no-color` disables colored output.
- `--no-input` disables interactive prompts.
