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
            .make(label: "due", names: [.short("d"), .long("due")], help: "Set due date", parsing: .singleValue),
            .make(label: "alarm", names: [.short("a"), .long("alarm")], help: "Set alarm date", parsing: .singleValue),
            .make(label: "notes", names: [.short("n"), .long("notes")], help: "Set notes", parsing: .singleValue),
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
      ]
    ) { values, runtime in
      guard let input = values.argument(0) else {
        throw ParsedValuesError.missingArgument("id")
      }

      let store = RemindersStore()
      try await store.requestAccess()
      let reminders = try await store.reminders(in: nil)
      let resolved = try IDResolver.resolve([input], from: reminders, indexedIDs: IndexCache.load())
      guard let reminder = resolved.first else {
        throw RemindCoreError.reminderNotFound(input)
      }

      let title = values.option("title")
      let listName = values.option("list")
      let notes = values.option("notes")
      let alarmValue = values.option("alarm")
      let repeatValue = values.option("repeat")

      var dueUpdate: ParsedUserDate??
      if let dueValue = values.option("due") {
        dueUpdate = try CommandHelpers.parseDueDate(dueValue)
      }
      if values.flag("clearDue") {
        if dueUpdate != nil {
          throw RemindCoreError.operationFailed("Use either --due or --clear-due, not both")
        }
        dueUpdate = .some(nil)
      }

      var alarmUpdate: ParsedUserDate??
      if let alarmValue {
        alarmUpdate = try CommandHelpers.parseDueDate(alarmValue)
      }
      if values.flag("clearAlarm") {
        if alarmUpdate != nil {
          throw RemindCoreError.operationFailed("Use either --alarm or --clear-alarm, not both")
        }
        alarmUpdate = .some(nil)
      }

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

      let hasChanges =
        title != nil || listName != nil || notes != nil || dueUpdate != nil || alarmUpdate != nil || priority != nil
        || recurrenceUpdate != nil || isCompleted != nil
      if !hasChanges {
        throw RemindCoreError.operationFailed("No changes specified")
      }

      let update = ReminderUpdate(
        title: title,
        notes: notes,
        dueDate: dueUpdate,
        alarmDate: alarmUpdate,
        recurrenceRule: recurrenceUpdate,
        priority: priority,
        listName: listName,
        isCompleted: isCompleted
      )

      let updated = try await store.updateReminder(id: reminder.id, update: update)
      OutputRenderer.printReminder(updated, format: runtime.outputFormat)
    }
  }
}
