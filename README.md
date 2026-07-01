# remindctl

![remindctl banner](docs/assets/readme-banner.jpg)

Fast command-line access to Apple Reminders on macOS.

`remindctl` is for scripts, agents, and terminal workflows that need to read and update the same reminders you see in Reminders.app. It uses Apple's public EventKit APIs, so reminders keep syncing through the normal system/iCloud path.

Docs: https://remindctl.sh

## Install

### Homebrew

```bash
brew install steipete/tap/remindctl
```

### From Source

```bash
pnpm install
pnpm build
# binary at ./bin/remindctl
```

## Requirements

- macOS 14+ (Sonoma or later)
- Swift 6.2+ when building from source
- Full Reminders access for the terminal app that runs `remindctl`

## Quick Start

```bash
remindctl add "Buy milk"
remindctl add "Call mom" --list Personal --due tomorrow
remindctl add "Meeting" --due "2026-01-03 09:00" --alarm "2026-01-03 08:55"
remindctl add "Buy headphones" --url "https://example.com/product"

remindctl today
remindctl overdue
remindctl open
remindctl list Work Errands
remindctl list --list-id 7A12
remindctl search "milk"
remindctl info 1
remindctl doctor --for-agent
remindctl export --list Work --export-format csv
remindctl link 1

remindctl edit 1 --title "New title" --due 2026-01-04
remindctl edit 1 --url "https://example.com/product"   # or --clear-url to remove it
remindctl complete 1 2 3
remindctl delete 4A83 --force
```

URLs remain stored in EventKit and are also mirrored to a `remindctl URL (managed): ...` notes line so they are visible in Reminders.app. `--clear-url` removes the EventKit value and only that managed notes line.

Indexes such as `1` come from the default reminder listing. Most commands also accept an ID prefix such as `4A83`.

## Commands

| Command | Purpose |
| --- | --- |
| `remindctl` / `remindctl today` | Show today's reminders |
| `remindctl show <filter>` | Show reminders by filter or date |
| `remindctl search <query>` | Search incomplete reminder titles, notes, and URLs |
| `remindctl info <id>` | Show detailed reminder metadata |
| `remindctl list` | Show reminder lists |
| `remindctl list <name...>` | Show reminders from one or more lists |
| `remindctl export` | Export reminders as JSON or CSV |
| `remindctl link <id>` | Print a best-effort Reminders deep link |
| `remindctl open <id>` | Open a reminder or list in Reminders.app |
| `remindctl doctor` | Diagnose permissions and read-only rich-store access |
| `remindctl add <title>` | Create a reminder |
| `remindctl edit <id>` | Edit a reminder by index or ID prefix |
| `remindctl complete <id...>` | Mark reminders complete |
| `remindctl delete <id...>` | Delete reminders |
| `remindctl status` | Show Reminders permission status |
| `remindctl authorize` | Request Reminders permission when macOS allows it |

Run `remindctl <command> --help` for the full option list.

## Showing Reminders

Common filters:

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

Search titles, notes, and URLs:

```bash
remindctl search "milk"
remindctl search "invoice" --list Work
remindctl search "project" --completed --json
```

Standard search output includes stable reminder IDs instead of numeric indexes.

Inspect one reminder:

```bash
remindctl info 1
remindctl info 4A83 --json
```

Limit a view to one list:

```bash
remindctl show overdue --list Work
remindctl show overdue --list-id 7A12
```

Show multiple lists together:

```bash
remindctl list Work Errands
```

## Lists

```bash
remindctl list
remindctl list Work
remindctl list Projects --create
remindctl list Work --rename Office
remindctl list OldList --delete --force
```

Mutating list operations accept one list name. Read-only list views can accept multiple names.
List names resolve by exact match, case-insensitive match, then a normalized match that ignores emoji and punctuation. If a name is ambiguous, use `--list-id`.

Exact list targeting:

```bash
remindctl list --list-id 7A12
remindctl add "Review notes" --list-id 7A12
remindctl edit 4A83 --list-id 7A12
remindctl list --list-id 7A12 --rename Archive
remindctl list --list-id 7A12 --delete --force
```

## Dates And Due Times

Accepted by `--due` and date filters:

- `today`, `tomorrow`, `yesterday`
- `YYYY-MM-DD`
- `YYYY-MM-DD HH:mm`
- ISO 8601 with timezone, such as `2026-01-03T12:34:56Z`
- Local ISO 8601 without timezone, such as `2026-01-03T12:34:56`

Date-only due values create all-day reminders. Date-time values create timed reminders.

## Alarms

Timed due reminders automatically get an EventKit notification alarm at the due time. Use `--alarm` to choose a different alarm time.

```bash
remindctl add "Meeting" --due "2026-01-03 09:00" --alarm "2026-01-03 08:55"
remindctl edit 4A83 --alarm "2026-01-03 08:55"
remindctl edit 4A83 --clear-alarm
```

This is public EventKit alarm support. Apple's private Reminders "Urgent" toggle is not exposed by EventKit.

## Repeat

Use `--repeat` with `add` or `edit` for simple recurrence:

```bash
remindctl add "Take vitamins" --due tomorrow --repeat daily
remindctl add "Water filter" --due "2026-09-13" --repeat "every 6 months"
remindctl edit 4A83 --repeat weekly
remindctl edit 4A83 --no-repeat
```

Supported repeat values:

- `daily`, `weekly`, `biweekly`, `monthly`, `yearly`
- `every N days/weeks/months/years`

## Location Triggers

Use `--location` on `add` to create an arriving geofence trigger. Add `--leaving` to trigger when leaving, and `--radius` to customize the geofence radius in meters.

```bash
remindctl add "Check mailbox" --location "1 Apple Park Way, Cupertino, CA"
remindctl add "Lock up" --location "Home" --leaving
remindctl add "Get groceries" --location "123 Main St" --radius 200
```

Location triggers use EventKit and CoreLocation geocoding. They may depend on system location services and network availability.

## Output

Global output flags:

- `--json` emits machine-readable JSON.
- `--plain` emits stable tab-separated lines.
- `--format table` emits tabular output for scan-heavy commands.
- `--quiet` emits minimal output, usually counts or nothing.
- `--no-color` disables colored output.
- `--no-input` disables interactive prompts.

JSON includes public EventKit metadata when available:

- `creationDate`
- `lastModifiedDate`
- `url`
- `alarmDate`
- `locationTrigger`
- `recurrenceRule`

Example:

```bash
remindctl all --json
remindctl today --format table
remindctl list --json
remindctl status --json
```

## Export, Links, And Completion

```bash
remindctl export --json
remindctl export --list Work --export-format csv
remindctl link 1
remindctl link --list-id 7A12
remindctl open 1
remindctl open --list Work
remindctl open --list Work --app
remindctl open --app
remindctl completion zsh
```

`link` and `open <id>` use best-effort Reminders deep links based on EventKit IDs. `open --list Work`
keeps the historical open-reminders filter; add `--app` to open that list in Reminders.app.

## Permissions

Check access:

```bash
remindctl status
remindctl doctor --for-agent
```

Request access:

```bash
remindctl authorize
```

If macOS reports access as denied, enable the terminal app in:

```text
System Settings > Privacy & Security > Reminders
```

If no prompt appears, run this once from the same terminal app:

```bash
osascript -e 'tell application "Reminders" to get name of reminders'
```

Then allow access and rerun:

```bash
remindctl status
```

When running over SSH, grant access on the Mac that actually runs `remindctl`.

## EventKit Limits

`remindctl` intentionally sticks to public EventKit APIs. These Reminders.app features are not exposed through EventKit today:

- Native Reminders sections
- Native Reminders tags and smart lists
- File/image attachments
- Apple's private "Urgent" toggle

Supporting those would require Apple to expose new public APIs or a separate non-EventKit backend.

## Development

```bash
make remindctl ARGS="status"   # clean build + run
make check                     # strict lint + tests + 90% coverage gate
make release-check TAG=vX.Y.Z  # validate release preflight
pnpm build                     # release build into ./bin/remindctl
```

Release steps live in [docs/RELEASING.md](docs/RELEASING.md).
