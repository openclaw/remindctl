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
        isFlagged: false,
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
        isFlagged: false,
        listID: "list1",
        listName: "Work"
      ),
    ]
  }

  @Test("Resolve by index")
  func resolveIndex() throws {
    let resolved = try IDResolver.resolve(["1"], from: sampleReminders())
    #expect(resolved.first?.title == "First")
  }

  @Test("Resolve by prefix")
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
