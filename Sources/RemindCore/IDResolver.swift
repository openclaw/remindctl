import Foundation

public enum IDResolver {
  public static let minimumPrefixLength = 4

  public static func resolve(
    _ inputs: [String],
    from reminders: [ReminderItem],
    indexedIDs: [String]? = nil
  ) throws -> [ReminderItem] {
    let sorted = ReminderFiltering.sort(reminders)
    var resolved: [ReminderItem] = []
    for input in inputs {
      let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
      if let index = Int(trimmed) {
        guard let indexedIDs else {
          throw RemindCoreError.operationFailed(
            "No recent `remindctl show` output to resolve index \(index). Run `remindctl show` first, or pass an ID prefix."
          )
        }
        let idx = index - 1
        guard idx >= 0 && idx < indexedIDs.count else {
          throw RemindCoreError.invalidIdentifier(trimmed)
        }
        let id = indexedIDs[idx]
        guard let match = sorted.first(where: { $0.id == id }) else {
          throw RemindCoreError.reminderNotFound(id)
        }
        resolved.append(match)
        continue
      }

      if trimmed.count < minimumPrefixLength {
        throw RemindCoreError.invalidIdentifier(trimmed)
      }

      let matches = sorted.filter { $0.id.lowercased().hasPrefix(trimmed.lowercased()) }
      if matches.isEmpty {
        throw RemindCoreError.reminderNotFound(trimmed)
      }
      if matches.count > 1 {
        throw RemindCoreError.ambiguousIdentifier(trimmed, matches: matches.map { $0.id })
      }
      if let match = matches.first {
        resolved.append(match)
      }
    }
    return resolved
  }
}
