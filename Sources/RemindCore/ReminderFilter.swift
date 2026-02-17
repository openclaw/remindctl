import Foundation

public enum ReminderFilter: Equatable, Sendable {
  case today
  case tomorrow
  case week
  case overdue
  case upcoming
  case completed
  case date(Date)
  case all
}

public enum ReminderFiltering {
  public static func parse(_ input: String, now: Date = Date(), calendar: Calendar = .current) -> ReminderFilter? {
    let token = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    switch token {
    case "today", "tday":
      return .today
    case "tomorrow", "t":
      return .tomorrow
    case "week", "w":
      return .week
    case "overdue", "o":
      return .overdue
    case "upcoming", "u":
      return .upcoming
    case "completed", "done", "c":
      return .completed
    case "all", "a":
      return .all
    default:
      if let parsed = DateParsing.parseUserDate(token, now: now, calendar: calendar) {
        return .date(parsed.date)
      }
      return nil
    }
  }

  public static func apply(
    _ reminders: [ReminderItem],
    filter: ReminderFilter,
    now: Date = Date(),
    calendar: Calendar = .current
  ) -> [ReminderItem] {
    let startOfToday = calendar.startOfDay(for: now)
    let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday
    let startOfDayAfterTomorrow =
      calendar.date(byAdding: .day, value: 2, to: startOfToday) ?? startOfTomorrow
    switch filter {
    case .today:
      return reminders.filter { reminder in
        let isToday = reminder.dueDate.map { $0 >= startOfToday && $0 < startOfTomorrow } ?? false
        let isOverdue = reminder.dueDate.map { $0 < startOfToday } ?? false
        return !reminder.isCompleted && (isToday || isOverdue)
      }
    case .tomorrow:
      return reminders.filter { reminder in
        let isTomorrow = reminder.dueDate.map { $0 >= startOfTomorrow && $0 < startOfDayAfterTomorrow } ?? false
        return !reminder.isCompleted && isTomorrow
      }
    case .week:
      let interval = calendar.dateInterval(of: .weekOfYear, for: now)
      let start = interval?.start ?? startOfToday
      let end = interval?.end ?? now
      return reminders.filter { reminder in
        let inWeek = reminder.dueDate.map { $0 >= start && $0 <= end } ?? false
        return !reminder.isCompleted && inWeek
      }
    case .overdue:
      return reminders.filter { reminder in
        let isOverdue = reminder.dueDate.map { $0 < startOfToday } ?? false
        return !reminder.isCompleted && isOverdue
      }
    case .upcoming:
      return reminders.filter { reminder in
        !reminder.isCompleted && reminder.dueDate != nil
      }
    case .completed:
      return reminders.filter { $0.isCompleted }
    case .date(let date):
      return reminders.filter { reminder in
        let matches = reminder.dueDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false
        return !reminder.isCompleted && matches
      }
    case .all:
      return reminders
    }
  }

  public static func sort(_ reminders: [ReminderItem]) -> [ReminderItem] {
    reminders.sorted { lhs, rhs in
      switch (lhs.dueDate, rhs.dueDate) {
      case (nil, nil):
        return lhs.title < rhs.title
      case (nil, _?):
        return false
      case (_?, nil):
        return true
      case (let left?, let right?):
        if left == right {
          return lhs.title < rhs.title
        }
        return left < right
      }
    }
  }
}
