import Foundation

public enum IDResolver {
  public static let minimumPrefixLength = 4

  public static func resolve(
    _ inputs: [String],
    from reminders: [ReminderItem],
    numericFrom numericReminders: [ReminderItem]? = nil
  ) throws -> [ReminderItem] {
    let sorted = ReminderFiltering.sort(reminders)
    let numericSorted = ReminderFiltering.sort(numericReminders ?? reminders)
    var resolved: [ReminderItem] = []
    var seen: Set<String> = []
    func appendUnique(_ item: ReminderItem) {
      if seen.insert(item.id).inserted {
        resolved.append(item)
      }
    }
    for input in inputs {
      let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
      if let index = Int(trimmed) {
        guard index > 0 && index <= numericSorted.count else {
          throw RemindCoreError.invalidIdentifier(trimmed)
        }
        appendUnique(numericSorted[index - 1])
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
        appendUnique(match)
      }
    }
    return resolved
  }
}
