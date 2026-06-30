import Commander
import Foundation
import RemindCore

enum AddCommand {
  static var spec: CommandSpec {
    CommandSpec(
      name: "add",
      abstract: "Add a reminder",
      discussion: "Provide a title as an argument or via --title.",
      signature: CommandSignatures.withRuntimeFlags(
        CommandSignature(
          arguments: [
            .make(label: "title", help: "Reminder title", isOptional: true)
          ],
          options: [
            .make(label: "title", names: [.long("title")], help: "Reminder title", parsing: .singleValue),
            .make(label: "list", names: [.short("l"), .long("list")], help: "List name", parsing: .singleValue),
            .make(label: "listID", names: [.long("list-id")], help: "List ID or ID prefix", parsing: .singleValue),
            .make(label: "due", names: [.short("d"), .long("due")], help: "Due date", parsing: .singleValue),
            .make(label: "alarm", names: [.short("a"), .long("alarm")], help: "Alarm date", parsing: .singleValue),
            .make(
              label: "location",
              names: [.long("location")],
              help: "Location address for geofence trigger",
              parsing: .singleValue
            ),
            .make(
              label: "radius",
              names: [.long("radius")],
              help: "Geofence radius in meters (default: 100)",
              parsing: .singleValue
            ),
            .make(label: "notes", names: [.short("n"), .long("notes")], help: "Notes", parsing: .singleValue),
            .make(
              label: "url",
              names: [.long("url")],
              help: "URL (stored in EventKit)",
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
            .make(label: "leaving", names: [.long("leaving")], help: "Trigger when leaving location"),
            .make(
              label: "showURLInNotes",
              names: [.long("show-url-in-notes")],
              help: "Mirror --url into a managed Reminders notes line"
            ),
          ]
        )
      ),
      usageExamples: [
        "remindctl add \"Buy milk\"",
        "remindctl add --title \"Call mom\" --list Personal --due tomorrow",
        "remindctl add \"Call mom\" --due \"2026-01-03 09:00\" --alarm \"2026-01-03 08:55\"",
        "remindctl add \"Check mailbox\" --location \"1 Apple Park Way, Cupertino, CA\"",
        "remindctl add \"Take vitamins\" --due tomorrow --repeat daily",
        "remindctl add \"Review docs\" --priority high",
        "remindctl add \"Buy headphones\" --url \"https://example.com/product\"",
      ]
    ) { values, runtime in
      let titleOption = values.option("title")
      let titleArg = values.argument(0)
      if titleOption != nil && titleArg != nil {
        throw RemindCoreError.operationFailed("Provide title either as argument or via --title")
      }

      var title = titleOption ?? titleArg
      if title == nil {
        if runtime.noInput || !Console.isTTY {
          throw RemindCoreError.operationFailed("Missing title. Provide it as an argument or via --title.")
        }
        title = Console.readLine(prompt: "Title:")?.trimmingCharacters(in: .whitespacesAndNewlines)
        if title?.isEmpty == true { title = nil }
      }

      guard let title else {
        throw RemindCoreError.operationFailed("Missing title.")
      }

      let listName = values.option("list")
      let listID = values.option("listID")
      let notes = values.option("notes")
      let url = try values.option("url").map(CommandHelpers.parseURL)
      let showURLInNotes = values.flag("showURLInNotes")
      if showURLInNotes && url == nil {
        throw RemindCoreError.operationFailed("Use --show-url-in-notes with --url")
      }
      let dueValue = values.option("due")
      let alarmValue = values.option("alarm")
      let locationValue = values.option("location")
      let radiusValue = values.option("radius")
      let repeatValue = values.option("repeat")
      let priorityValue = values.option("priority")

      let dueDate = try dueValue.map(CommandHelpers.parseDueDate)
      let alarmDate = try alarmValue.map(CommandHelpers.parseDueDate)
      let locationTrigger = try makeLocationTrigger(
        location: locationValue,
        radius: radiusValue,
        leaving: values.flag("leaving")
      )
      let recurrenceRule = try repeatValue.map(CommandHelpers.parseRecurrence)
      let priority = try priorityValue.map(CommandHelpers.parsePriority) ?? .none

      let store = RemindersStore()
      try await store.requestAccess()

      let targetList: ReminderListTarget?
      if let explicitTarget = try CommandHelpers.listTarget(name: listName, id: listID) {
        targetList = explicitTarget
      } else {
        targetList = await store.defaultList().map { .id($0.id) }
      }
      guard let targetList else {
        throw RemindCoreError.operationFailed("No default list found. Specify --list.")
      }

      let draft = ReminderDraft(
        title: title,
        notes: notes,
        url: url,
        showURLInNotes: showURLInNotes,
        dueDate: dueDate,
        alarmDate: alarmDate,
        recurrenceRule: recurrenceRule,
        locationTrigger: locationTrigger,
        priority: priority
      )
      let reminder = try await store.createReminder(draft, target: targetList)
      OutputRenderer.printReminder(reminder, format: runtime.outputFormat)
    }
  }

  private static func makeLocationTrigger(
    location: String?,
    radius: String?,
    leaving: Bool
  ) throws -> LocationTrigger? {
    if location == nil {
      if radius != nil || leaving {
        throw RemindCoreError.operationFailed("Use --location with --radius or --leaving")
      }
      return nil
    }
    guard let location else { return nil }
    let radius = try radius.map(parseRadius) ?? 100
    return LocationTrigger(
      address: location,
      radius: radius,
      proximity: leaving ? .leaving : .arriving
    )
  }

  private static func parseRadius(_ value: String) throws -> Double {
    guard let radius = Double(value), radius > 0 else {
      throw RemindCoreError.operationFailed("Invalid radius: \"\(value)\"")
    }
    return radius
  }
}
