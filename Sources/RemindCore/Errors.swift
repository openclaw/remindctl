import Foundation

public enum RemindCoreError: LocalizedError, Sendable, Equatable {
  case accessDenied
  case writeOnlyAccess
  case listNotFound(String)
  case reminderNotFound(String)
  case ambiguousIdentifier(String, matches: [String])
  case invalidIdentifier(String)
  case numericIndexWithoutContext(Int)
  case invalidDate(String)
  case unsupported(String)
  case operationFailed(String)

  public var errorDescription: String? {
    switch self {
    case .accessDenied:
      return [
        "Reminders access denied.",
        "Run `remindctl authorize` to trigger the prompt, then allow Terminal (or remindctl)",
        "in System Settings > Privacy & Security > Reminders.",
        "If no prompt appears, run `osascript -e 'tell application \"Reminders\" to get name of reminders'`",
        "once from the same terminal app.",
        "If running over SSH, grant access on the Mac that runs the command.",
      ].joined(separator: " ")
    case .writeOnlyAccess:
      return [
        "Reminders access is write-only.",
        "Switch to Full Access in System Settings > Privacy & Security > Reminders.",
      ].joined(separator: " ")
    case .listNotFound(let name):
      return "List not found: \"\(name)\"."
    case .reminderNotFound(let id):
      return "Reminder not found: \"\(id)\"."
    case .ambiguousIdentifier(let input, let matches):
      return "Identifier \"\(input)\" matches multiple reminders: \(matches.joined(separator: ", "))."
    case .invalidIdentifier(let input):
      return "Invalid identifier: \"\(input)\"."
    case .numericIndexWithoutContext(let index):
      return [
        "No recent `remindctl show` output to resolve index \(index).",
        "Run `remindctl show` first, or pass an ID prefix.",
      ].joined(separator: " ")
    case .invalidDate(let input):
      return "Invalid date: \"\(input)\"."
    case .unsupported(let message):
      return message
    case .operationFailed(let message):
      return message
    }
  }
}
