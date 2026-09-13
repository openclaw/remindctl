import AppKit
import Commander
import Foundation
import RemindCore

enum OpenCommand {
  static var spec: CommandSpec {
    CommandSpec(
      name: "open",
      abstract: "Open reminders or Reminders.app",
      discussion: "Without an ID, keeps the historical behavior and shows open reminders.",
      signature: CommandSignatures.withRuntimeFlags(
        CommandSignature(
          arguments: [
            .make(label: "id", help: "Reminder index or ID prefix", isOptional: true)
          ],
          options: [
            .make(
              label: "list",
              names: [.short("l"), .long("list")],
              help: "Open a list by name",
              parsing: .singleValue
            ),
            .make(
              label: "listID",
              names: [.long("list-id")],
              help: "Open a list by ID or ID prefix",
              parsing: .singleValue
            ),
          ],
          flags: [
            .make(label: "app", names: [.long("app")], help: "Open Reminders.app")
          ]
        )
      ),
      usageExamples: [
        "remindctl open",
        "remindctl open 1",
        "remindctl open --list Work",
        "remindctl open --list Work --app",
        "remindctl open --app",
      ]
    ) { values, runtime in
      let listTarget = try CommandHelpers.listTarget(name: values.option("list"), id: values.option("listID"))
      if shouldShowOpenReminders(
        id: values.argument(0),
        listName: values.option("list"),
        listID: values.option("listID"),
        app: values.flag("app")
      ) {
        let store = RemindersStore()
        try await store.requestAccess()
        let reminders = try await store.reminders(matching: listTarget)
        OutputRenderer.printReminders(ReminderFiltering.apply(reminders, filter: .open), format: runtime.outputFormat)
        return
      }

      let url: URL
      if values.flag("app"), values.argument(0) == nil, listTarget == nil {
        url = URL(string: "x-apple-reminderkit://")!
      } else {
        let result = try await LinkCommand.resolve(values: values)
        guard let parsed = URL(string: result.url) else {
          throw RemindCoreError.operationFailed("Invalid Reminders URL")
        }
        url = parsed
      }
      guard NSWorkspace.shared.open(url) else {
        throw RemindCoreError.operationFailed("Could not open \(url.absoluteString)")
      }
      if runtime.outputFormat == .json {
        OutputRenderer.printJSON(["opened": url.absoluteString])
      } else if runtime.outputFormat != .quiet {
        Swift.print("Opened \(url.absoluteString)")
      }
    }
  }

  static func shouldShowOpenReminders(id: String?, listName _: String?, listID _: String?, app: Bool) -> Bool {
    id == nil && !app
  }
}
