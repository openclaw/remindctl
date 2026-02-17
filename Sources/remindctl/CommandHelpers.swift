import Foundation
import RemindCore

enum CommandHelpers {
  static func parsePriority(_ value: String) throws -> ReminderPriority {
    switch value.lowercased() {
    case "none":
      return .none
    case "low":
      return .low
    case "medium", "med":
      return .medium
    case "high":
      return .high
    default:
      throw RemindCoreError.operationFailed("Invalid priority: \"\(value)\" (use none|low|medium|high)")
    }
  }

  static func parseDueDate(_ value: String) throws -> ParsedDate {
    guard let parsed = DateParsing.parseUserDate(value) else {
      throw RemindCoreError.invalidDate(value)
    }
    return parsed
  }
}
