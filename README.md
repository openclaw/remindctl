# remindctl

Forget the app, not the task ✅

Fast CLI for Apple Reminders on macOS.

## Install

### Homebrew
```bash
brew install steipete/tap/remindctl
```

### From source
```bash
pnpm install
pnpm build
# binary at ./bin/remindctl
```

## Development
```bash
make remindctl ARGS="status"   # clean build + run
make check                     # lint + test + coverage gate
```

## Requirements
- macOS 14+ (Sonoma or later)
- Swift 6.2+
- Reminders permission (System Settings → Privacy & Security → Reminders)

## Usage
```bash
remindctl                      # show today (default)
remindctl today                 # show today
remindctl tomorrow              # show tomorrow
remindctl week                  # show this week
remindctl overdue               # overdue
remindctl upcoming              # upcoming
remindctl open                  # all incomplete reminders
remindctl completed             # completed
remindctl all                   # all reminders
remindctl 2026-01-03            # specific date

remindctl list                  # lists
remindctl list Work             # show list
remindctl list Work --rename Office
remindctl list Work --delete
remindctl list Projects --create

remindctl add "Buy milk"
remindctl add --title "Call mom" --list Personal --due tomorrow
remindctl add "Meeting" --due "2026-01-03 09:00"
remindctl edit 1 --title "New title" --due 2026-01-04
remindctl list Work Errands       # show reminders from multiple lists
remindctl complete 1 2 3
remindctl delete 4A83 --force
remindctl status                # permission status
remindctl authorize             # request permissions
```

## Output formats
- `--json` emits JSON arrays/objects.
- `--plain` emits tab-separated lines.
- `--quiet` emits counts only.
- JSON includes EventKit metadata such as `creationDate`, `lastModifiedDate`, `url`, `alarmDate`,
  `locationTrigger`, and `recurrenceRule` when available.
  File/image attachments are not exposed by EventKit.

## Date formats
Accepted by `--due` and filters:
- `today`, `tomorrow`, `yesterday`
- `YYYY-MM-DD`
- `YYYY-MM-DD HH:mm`
- ISO 8601 (`2026-01-03T12:34:56Z`)
- Local ISO 8601 without timezone (`2026-01-03T12:34:56`)

Date-only due inputs create all-day reminders; date-time inputs create timed reminders.

## Alarms
Timed due reminders get a notification alarm at the due time unless `--alarm` sets a different alarm time.

```bash
remindctl add "Meeting" --due "2026-01-03 09:00" --alarm "2026-01-03 08:55"
remindctl edit 4A83 --alarm "2026-01-03 08:55"
remindctl edit 4A83 --clear-alarm
```

This is public EventKit alarm support, not Apple's private Reminders "Urgent" toggle.

## Repeat
Use `--repeat` with `add` or `edit` for simple recurrence:
- `daily`, `weekly`, `biweekly`, `monthly`, `yearly`
- `every N days/weeks/months/years`

Use `edit <id> --no-repeat` to clear recurrence.

```bash
remindctl add "Take vitamins" --due tomorrow --repeat daily
remindctl add "Water filter" --due "2026-09-13" --repeat "every 6 months"
remindctl edit 4A83 --repeat weekly
remindctl edit 4A83 --no-repeat
```

## Location Triggers
Use `--location <address>` on `add` to create a location trigger. Add `--leaving` to trigger when leaving
instead of arriving, and `--radius <meters>` to customize the geofence radius.

```bash
remindctl add "Check mailbox" --location "1 Apple Park Way, Cupertino, CA"
remindctl add "Lock up" --location "Home" --leaving
remindctl add "Get groceries" --location "123 Main St" --radius 200
```

Location triggers use EventKit/CoreLocation geocoding and may depend on system location services.

## Unsupported
- Native Reminders sections are not exposed by EventKit; section support would need a separate backend.
- Native Reminders tags and smart lists are not exposed by EventKit.
- File/image attachments are not exposed by EventKit.

## Permissions
Run `remindctl authorize` to trigger the system prompt. If access is denied, enable
Terminal (or remindctl) in System Settings → Privacy & Security → Reminders.
If running over SSH, grant access on the Mac that runs the command.
If no prompt appears in your terminal app, run:

```bash
osascript -e 'tell application "Reminders" to get name of reminders'
```

Then allow access and rerun `remindctl status`.
