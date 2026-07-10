---
title: Permissions
description: "macOS Reminders permissions for remindctl."
---

# Permissions

`remindctl` uses EventKit. macOS grants Reminders access per app, so the terminal app that runs `remindctl` must have permission.

## Check access

```bash
remindctl status
```

## Request access

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

## Signed binary upgrades

Observed development grants are attributed to the host terminal application (Terminal or Ghostty), not to the `remindctl` executable. The official binary keeps the identifier `com.steipete.remindctl`, but identifier continuity alone does not prove that macOS will preserve Reminders access while the signing Team changes to OpenClaw Foundation.

Release qualification therefore includes a separate clean-VM migration gate. Until that test records the actual TCC principal and proves read/write behavior across the upgrade, release notes and support guidance must not claim permission continuity.
