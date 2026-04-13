import Foundation
import Testing

@testable import RemindCore

@MainActor
struct ReminderFilteringTests {
  private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
    return calendar
  }()

  private func reminders(now: Date) -> [ReminderItem] {
    let today = calendar.startOfDay(for: now)
    let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
    let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
    return [
      ReminderItem(
        id: "1",
        title: "Overdue",
        notes: nil,
        isCompleted: false,
        completionDate: nil,
        priority: .none,
        dueDate: yesterday,
        isFlagged: false,
        listID: "a",
        listName: "Home"
      ),
      ReminderItem(
        id: "2",
        title: "Today",
        notes: nil,
        isCompleted: false,
        completionDate: nil,
        priority: .none,
        dueDate: today,
        isFlagged: false,
        listID: "a",
        listName: "Home"
      ),
      ReminderItem(
        id: "3",
        title: "Tomorrow",
        notes: nil,
        isCompleted: false,
        completionDate: nil,
        priority: .none,
        dueDate: tomorrow,
        isFlagged: false,
        listID: "a",
        listName: "Home"
      ),
      ReminderItem(
        id: "5",
        title: "No Due",
        notes: nil,
        isCompleted: false,
        completionDate: nil,
        priority: .none,
        dueDate: nil,
        isFlagged: false,
        listID: "a",
        listName: "Home"
      ),
      ReminderItem(
        id: "4",
        title: "Completed",
        notes: nil,
        isCompleted: true,
        completionDate: now,
        priority: .none,
        dueDate: today,
        isFlagged: false,
        listID: "a",
        listName: "Home"
      ),
    ]
  }

  @Test("Today filter includes overdue")
  func todayIncludesOverdue() {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let items = reminders(now: now)
    let result = ReminderFiltering.apply(items, filter: .today, now: now, calendar: calendar)
    #expect(result.count == 2)
  }

  @Test("Tomorrow filter")
  func tomorrowFilter() {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let items = reminders(now: now)
    let result = ReminderFiltering.apply(items, filter: .tomorrow, now: now, calendar: calendar)
    #expect(result.count == 1)
    #expect(result.first?.title == "Tomorrow")
  }

  @Test("Overdue filter")
  func overdueFilter() {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let items = reminders(now: now)
    let result = ReminderFiltering.apply(items, filter: .overdue, now: now, calendar: calendar)
    #expect(result.count == 1)
    #expect(result.first?.title == "Overdue")
  }

  @Test("Upcoming filter ignores no due date")
  func upcomingFilter() {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let items = reminders(now: now)
    let result = ReminderFiltering.apply(items, filter: .upcoming, now: now, calendar: calendar)
    #expect(result.count == 3)
  }

  @Test("Date filter")
  func dateFilter() {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let items = reminders(now: now)
    let today = calendar.startOfDay(for: now)
    let result = ReminderFiltering.apply(items, filter: .date(today), now: now, calendar: calendar)
    #expect(result.count == 1)
    #expect(result.first?.title == "Today")
  }

  @Test("All filter includes completed")
  func allFilter() {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let items = reminders(now: now)
    let result = ReminderFiltering.apply(items, filter: .all, now: now, calendar: calendar)
    #expect(result.count == items.count)
  }

  @Test("Sort orders by due date then title")
  func sortOrder() {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let items = reminders(now: now)
    let sorted = ReminderFiltering.sort(items)
    #expect(sorted.first?.title == "Overdue")
    #expect(sorted.last?.title == "No Due")
  }

  @Test("Completed filter")
  func completedFilter() {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let items = reminders(now: now)
    let result = ReminderFiltering.apply(items, filter: .completed, now: now, calendar: calendar)
    #expect(result.count == 1)
    #expect(result.first?.title == "Completed")
  }
}
