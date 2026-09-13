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

  @Test("Resolve by index")
  func resolveIndex() throws {
    let resolved = try IDResolver.resolve(["1"], from: sampleReminders())
    #expect(resolved.first?.title == "First")
  }

  @Test("Resolve numeric indexes from filtered show output")
  func resolveIndexFromFilteredShowOutput() throws {
    let all = sampleReminders()
    let resolved = try IDResolver.resolve(["1"], from: all, numericFrom: [all[1]])
    #expect(resolved.first?.title == "Second")
  }

  @Test("Reject out-of-range indexes without overflow", arguments: [Int.min, -1, 0, 3, Int.max])
  func rejectInvalidIndex(_ index: Int) {
    let input = String(index)
    #expect(throws: RemindCoreError.invalidIdentifier(input)) {
      _ = try IDResolver.resolve([input], from: sampleReminders())
    }
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
