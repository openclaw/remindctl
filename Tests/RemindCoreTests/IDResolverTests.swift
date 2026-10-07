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

  @Test(
    "Repeated identifiers resolve each reminder once",
    arguments: [
      ["1", "1"],
      ["abcd1234", "abcd1234"],
      ["1", "abcd", " ABCD1234 "],
      ["abcd", "1"],
    ])
  func duplicateIDsResolveOnce(_ inputs: [String]) throws {
    let resolved = try IDResolver.resolve(inputs, from: sampleReminders())
    #expect(resolved.map(\.id) == ["abcd1234"])
  }

  @Test("Deduplication preserves first occurrence order")
  func duplicateIDsPreserveInputOrder() throws {
    let resolved = try IDResolver.resolve(["2", "1", "abce", "abcd"], from: sampleReminders())
    #expect(resolved.map(\.id) == ["abce5678", "abcd1234"])
  }

  @Test("Deduplication uses reminder identity across filtered numeric indexes")
  func duplicateIDsFromFilteredShowOutput() throws {
    let all = sampleReminders()
    let resolved = try IDResolver.resolve(["1", "abce5678", "abcd", "1"], from: all, numericFrom: [all[1]])
    #expect(resolved.map(\.id) == ["abce5678", "abcd1234"])
  }

  @Test("Duplicate targets do not hide invalid subsequent identifiers")
  func duplicateIDsStillValidateEveryInput() {
    #expect(throws: RemindCoreError.reminderNotFound("missing")) {
      _ = try IDResolver.resolve(["1", "1", "missing"], from: sampleReminders())
    }
  }

  @Test("Resolve numeric indexes from filtered show output")
  func resolveIndexFromFilteredShowOutput() throws {
    let all = sampleReminders()
    let resolved = try IDResolver.resolve(["1"], from: all, numericFrom: [all[1]])
    #expect(resolved.first?.title == "Second")
  }

  @Test("Numeric indexes survive reordered fetches with tied sort keys", arguments: [true, false])
  func stableIndexesWithTiedSortKeys(hasDueDate: Bool) throws {
    let items = ["aaaa-1111", "bbbb-2222", "cccc-3333"].map { id in
      ReminderItem(
        id: id,
        title: "Pay invoice",
        notes: nil,
        isCompleted: false,
        completionDate: nil,
        priority: .none,
        dueDate: hasDueDate ? Date(timeIntervalSince1970: 1_700_000_000) : nil,
        listID: "synthetic",
        listName: "Synthetic"
      )
    }
    let displayed = ReminderFiltering.sort(items)
    let fetched = Array(items.reversed())
    #expect(ReminderFiltering.sort(fetched).map(\.id) == displayed.map(\.id))
    for (index, reminder) in displayed.enumerated() {
      let resolved = try IDResolver.resolve([String(index + 1)], from: fetched, numericFrom: fetched)
      #expect(resolved.first?.id == reminder.id)
    }
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
