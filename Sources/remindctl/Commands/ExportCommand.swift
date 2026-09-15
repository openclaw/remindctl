import Commander
import Foundation
import RemindCore

enum ExportCommand {
  enum ExportOutput: Equatable {
    case json
    case csv
    case rendered(OutputFormat)
  }

  static var spec: CommandSpec {
    CommandSpec(
      name: "export",
      abstract: "Export reminders",
      discussion: "Exports reminders as JSON or CSV. Completed reminders are included.",
      signature: CommandSignatures.withRuntimeFlags(
        CommandSignature(
          options: [
            .make(
              label: "list",
              names: [.short("l"), .long("list")],
              help: "Export one list by name",
              parsing: .singleValue
            ),
            .make(
              label: "listID",
              names: [.long("list-id")],
              help: "Export one list by ID or ID prefix",
              parsing: .singleValue
            ),
            .make(
              label: "exportFormat",
              names: [.long("export-format")],
              help: "Export format: json|csv",
              parsing: .singleValue
            ),
          ]
        )
      ),
      usageExamples: [
        "remindctl export",
        "remindctl export --list Work --export-format csv",
        "remindctl export --list-id 7A12 --json",
      ]
    ) { values, runtime in
      let store = RemindersStore()
      try await store.requestAccess()
      let target = try CommandHelpers.listTarget(name: values.option("list"), id: values.option("listID"))
      let reminders = try await store.reminders(matching: target)
      let sorted = ReminderFiltering.sort(reminders)

      switch try outputMode(exportFormat: values.option("exportFormat"), runtimeFormat: runtime.outputFormat) {
      case .json:
        OutputRenderer.printJSON(sorted)
      case .csv:
        printCSV(sorted)
      case .rendered(let format):
        OutputRenderer.printReminders(sorted, format: format)
      }
    }
  }

  static func outputMode(exportFormat: String?, runtimeFormat: OutputFormat) throws -> ExportOutput {
    switch runtimeFormat {
    case .json:
      return .json
    case .plain, .table, .quiet:
      return .rendered(runtimeFormat)
    case .standard:
      switch exportFormat?.lowercased() {
      case nil, "json":
        return .json
      case "csv":
        return .csv
      default:
        throw RemindCoreError.operationFailed("Invalid export format: \"\(exportFormat ?? "")\" (use json|csv)")
      }
    }
  }

  private static func printCSV(_ reminders: [ReminderItem]) {
    let rows = ReminderFiltering.sort(reminders).map { reminder in
      [
        reminder.id,
        reminder.title,
        reminder.listName,
        reminder.isCompleted ? "1" : "0",
        reminder.priority.rawValue,
        reminder.dueDate.map { ISO8601DateFormatter().string(from: $0) } ?? "",
        reminder.notes ?? "",
        reminder.url?.absoluteString ?? "",
      ]
    }
    let header = ["id", "title", "list", "completed", "priority", "dueDate", "notes", "url"]
    for row in [header] + rows {
      Swift.print(row.map(csvField).joined(separator: ","))
    }
  }

  static func csvField(_ value: String) -> String {
    let sanitized = neutralizeSpreadsheetFormula(value)
    if sanitized.contains("\"") || sanitized.contains(",") || sanitized.contains(where: \.isNewline) {
      return "\"\(sanitized.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
    return sanitized
  }

  static func neutralizeSpreadsheetFormula(_ value: String) -> String {
    let trimmed = value.drop { $0 == " " || $0 == "\t" || $0.isNewline }
    guard let first = trimmed.first, ["=", "+", "-", "@"].contains(first) else {
      return value
    }
    return "'\(value)"
  }
}
