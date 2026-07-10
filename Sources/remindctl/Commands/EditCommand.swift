import Commander
import Foundation
import RemindCore

enum EditCommand {
  static var spec: CommandSpec {
    CommandSpec(
      name: "edit",
      abstract: "Edit a reminder",
      discussion: "Use an index or ID prefix from the show output.",
      signature: CommandSignatures.withRuntimeFlags(
        CommandSignature(
          arguments: [
            .make(label: "id", help: "Index or ID prefix", isOptional: false)
          ],
          options: [
            .make(label: "title", names: [.short("t"), .long("title")], help: "New title", parsing: .singleValue),
            .make(label: "list", names: [.short("l"), .long("list")], help: "Move to list", parsing: .singleValue),
            .make(
              label: "listID", names: [.long("list-id")], help: "Move to list by ID or ID prefix", parsing: .singleValue
            ),
            .make(label: "due", names: [.short("d"), .long("due")], help: "Set due date", parsing: .singleValue),
            .make(label: "alarm", names: [.short("a"), .long("alarm")], help: "Set alarm date", parsing: .singleValue),
            .make(label: "notes", names: [.short("n"), .long("notes")], help: "Set notes", parsing: .singleValue),
            .make(
              label: "url",
              names: [.long("url")],
              help: "Set URL (stored in EventKit and shown in Reminders notes)",
              parsing: .singleValue
            ),
            .make(
              label: "repeat",
              names: [.short("r"), .long("repeat")],
              help: "daily|weekly|biweekly|monthly|yearly|every N days/weeks/months/years",
              parsing: .singleValue
            ),
            .make(
              label: "priority",
              names: [.short("p"), .long("priority")],
              help: "none|low|medium|high",
              parsing: .singleValue
            ),
          ],
          flags: [
            .make(label: "clearDue", names: [.long("clear-due")], help: "Clear due date"),
            .make(label: "clearAlarm", names: [.long("clear-alarm")], help: "Clear alarm"),
            .make(label: "clearUrl", names: [.long("clear-url")], help: "Clear URL"),
            .make(label: "noRepeat", names: [.long("no-repeat")], help: "Remove recurrence"),
            .make(label: "complete", names: [.long("complete")], help: "Mark completed"),
            .make(label: "incomplete", names: [.long("incomplete")], help: "Mark incomplete"),
          ]
        )
      ),
      usageExamples: [
        "remindctl edit 1 --title \"New title\"",
        "remindctl edit 4A83 --due tomorrow",
        "remindctl edit 4A83 --alarm \"2026-01-03 08:55\"",
        "remindctl edit 4A83 --repeat weekly",
        "remindctl edit 2 --priority high --notes \"Call before noon\"",
        "remindctl edit 3 --clear-due --clear-alarm --no-repeat",
        "remindctl edit 4A83 --url \"https://example.com/product\"",
        "remindctl edit 4A83 --clear-url",
      ]
    ) { values, runtime in
      guard let input = values.argument(0) else {
        throw ParsedValuesError.missingArgument("id")
      }

      let store = RemindersStore()
      try await store.requestAccess()
      let reminders = try await store.reminders(in: nil)
      let resolved = try CommandHelpers.resolveShowIdentifiers([input], from: reminders)
      guard let reminder = resolved.first else {
        throw RemindCoreError.reminderNotFound(input)
      }

      let title = values.option("title")
      let listName = values.option("list")
      let listID = values.option("listID")
      let notes = values.option("notes")
      let alarmValue = values.option("alarm")
      let repeatValue = values.option("repeat")

      let urlUpdate = try parsedURLUpdate(urlValue: values.option("url"), clearURL: values.flag("clearUrl"))

      let dateUpdates = try parsedDateUpdates(
        dueValue: values.option("due"),
        clearDue: values.flag("clearDue"),
        alarmValue: alarmValue,
        clearAlarm: values.flag("clearAlarm")
      )

      var recurrenceUpdate: RecurrenceRule??
      if let repeatValue {
        recurrenceUpdate = try CommandHelpers.parseRecurrence(repeatValue)
      }
      if values.flag("noRepeat") {
        if recurrenceUpdate != nil {
          throw RemindCoreError.operationFailed("Use either --repeat or --no-repeat, not both")
        }
        recurrenceUpdate = .some(nil)
      }

      var priority: ReminderPriority?
      if let priorityValue = values.option("priority") {
        priority = try CommandHelpers.parsePriority(priorityValue)
      }

      let completeFlag = values.flag("complete")
      let incompleteFlag = values.flag("incomplete")
      if completeFlag && incompleteFlag {
        throw RemindCoreError.operationFailed("Use either --complete or --incomplete, not both")
      }
      let isCompleted: Bool? = completeFlag ? true : (incompleteFlag ? false : nil)

      let targetList = try CommandHelpers.listTarget(name: listName, id: listID)

      let hasChanges =
        title != nil || targetList != nil || notes != nil || urlUpdate != nil || dateUpdates.dueDate != nil
        || dateUpdates.alarmDate != nil || priority != nil || recurrenceUpdate != nil || isCompleted != nil
      if !hasChanges {
        throw RemindCoreError.operationFailed("No changes specified")
      }

      let update = ReminderUpdate(
        title: title,
        notes: notes,
        url: urlUpdate,
        dueDate: dateUpdates.dueDate,
        alarmDate: dateUpdates.alarmDate,
        recurrenceRule: recurrenceUpdate,
        priority: priority,
        listTarget: targetList,
        isCompleted: isCompleted
      )

      let updated = try await store.updateReminder(id: reminder.id, update: update)
      OutputRenderer.printReminder(updated, format: runtime.outputFormat)
    }
  }

  static func parsedURLUpdate(urlValue: String?, clearURL: Bool) throws -> URL?? {
    if let urlValue {
      if clearURL {
        throw RemindCoreError.operationFailed("Use either --url or --clear-url, not both")
      }
      return try CommandHelpers.parseURL(urlValue)
    }
    return clearURL ? .some(nil) : nil
  }

  struct DateUpdates {
    let dueDate: ParsedUserDate??
    let alarmDate: ParsedUserDate??
  }

  static func parsedDateUpdates(
    dueValue: String?,
    clearDue: Bool,
    alarmValue: String?,
    clearAlarm: Bool
  ) throws -> DateUpdates {
    if dueValue != nil && clearDue {
      throw RemindCoreError.operationFailed("Use either --due or --clear-due, not both")
    }
    if alarmValue != nil && clearAlarm {
      throw RemindCoreError.operationFailed("Use either --alarm or --clear-alarm, not both")
    }

    let dueDate: ParsedUserDate?? =
      if let dueValue {
        try CommandHelpers.parseDueDate(dueValue)
      } else if clearDue {
        .some(nil)
      } else {
        nil
      }
    let alarmDate: ParsedUserDate?? =
      if let alarmValue {
        try CommandHelpers.parseDueDate(alarmValue)
      } else if clearAlarm {
        .some(nil)
      } else {
        nil
      }
    return DateUpdates(dueDate: dueDate, alarmDate: alarmDate)
  }
}
