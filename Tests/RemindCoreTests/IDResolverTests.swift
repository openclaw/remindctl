import Foundation
import Testing

@testable import RemindCore

@MainActor
struct IDResolverTests {
  private func sampleReminders() -> [ReminderItem] {
    [
      ReminderItem(
        id: "abcd1234",
        title: "First",
        notes: nil,
        isCompleted: false,
        completionDate: nil,
        priority: .none,
        dueDate: Date(timeIntervalSince1970: 1_700_000_000),
        listID: "list1",
        listName: "Work"
      ),
      ReminderItem(
        id: "abce5678",
        title: "Second",
        notes: nil,
        isCompleted: false,
        completionDate: nil,
        priority: .none,
        dueDate: Date(timeIntervalSince1970: 1_700_000_100),
        listID: "list1",
        listName: "Work"
      ),
    ]
  }

  @Test("Resolve by index uses indexedIDs")
  func resolveIndex() throws {
    let resolved = try IDResolver.resolve(
      ["2"],
      from: sampleReminders(),
      indexedIDs: ["abcd1234", "abce5678"]
    )
    #expect(resolved.first?.title == "Second")
  }

  @Test("Numeric input without indexedIDs throws")
  func numericWithoutIndexedIDsThrows() {
    #expect(throws: Error.self) {
      _ = try IDResolver.resolve(["1"], from: sampleReminders())
    }
  }

  @Test("Numeric out of range throws")
  func numericOutOfRangeThrows() {
    #expect(throws: Error.self) {
      _ = try IDResolver.resolve(
        ["3"],
        from: sampleReminders(),
        indexedIDs: ["abcd1234", "abce5678"]
      )
    }
  }

  @Test("Cached ID missing from live reminders throws reminderNotFound")
  func cachedIDDeletedThrows() {
    #expect(throws: RemindCoreError.reminderNotFound("zzzzzzzz")) {
      _ = try IDResolver.resolve(
        ["1"],
        from: sampleReminders(),
        indexedIDs: ["zzzzzzzz"]
      )
    }
  }

  @Test("Resolve by prefix works without indexedIDs")
  func resolvePrefix() throws {
    let resolved = try IDResolver.resolve(["abcd"], from: sampleReminders())
    #expect(resolved.first?.title == "First")
  }

  @Test("Reject short prefix")
  func rejectShortPrefix() {
    #expect(throws: RemindCoreError.invalidIdentifier("ab")) {
      _ = try IDResolver.resolve(["ab"], from: sampleReminders())
    }
  }
}
