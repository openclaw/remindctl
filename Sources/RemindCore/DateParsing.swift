import Foundation

public struct ParsedDate: Sendable, Equatable {
  public let date: Date
  public let isDateOnly: Bool

  public init(date: Date, isDateOnly: Bool) {
    self.date = date
    self.isDateOnly = isDateOnly
  }
}

public enum DateParsing {
  public static func parseUserDate(
    _ input: String,
    now: Date = Date(),
    calendar: Calendar = .current
  ) -> ParsedDate? {
    let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
    let lower = trimmed.lowercased()

    if let relative = parseRelativeDate(lower, now: now, calendar: calendar) {
      return relative
    }

    let iso =
      isoFormatter(withFraction: true).date(from: trimmed)
      ?? isoFormatter(withFraction: false).date(from: trimmed)
    if let iso {
      return ParsedDate(date: iso, isDateOnly: false)
    }

    for (formatter, dateOnly) in dateFormattersWithContext() {
      if let date = formatter.date(from: trimmed) {
        return ParsedDate(date: date, isDateOnly: dateOnly)
      }
    }

    return nil
  }

  public static func formatDisplay(
    _ date: Date, isDateOnly: Bool = false, calendar: Calendar = .current
  ) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale.current
    formatter.timeZone = calendar.timeZone
    formatter.dateStyle = .medium
    formatter.timeStyle = isDateOnly ? .none : .short
    return formatter.string(from: date)
  }

  private static func parseRelativeDate(
    _ input: String, now: Date, calendar: Calendar
  ) -> ParsedDate? {
    switch input {
    case "today":
      return ParsedDate(date: calendar.startOfDay(for: now), isDateOnly: true)
    case "tomorrow":
      return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
        .map { ParsedDate(date: $0, isDateOnly: true) }
    case "yesterday":
      return calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now))
        .map { ParsedDate(date: $0, isDateOnly: true) }
    case "now":
      return ParsedDate(date: now, isDateOnly: false)
    default:
      return nil
    }
  }

  private static func isoFormatter(withFraction: Bool) -> ISO8601DateFormatter {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions =
      withFraction
      ? [.withInternetDateTime, .withFractionalSeconds]
      : [.withInternetDateTime]
    return formatter
  }

  private static func dateFormattersWithContext() -> [(DateFormatter, Bool)] {
    let formats: [(String, Bool)] = [
      ("yyyy-MM-dd", true),
      ("yyyy-MM-dd HH:mm", false),
      ("yyyy-MM-dd HH:mm:ss", false),
      ("MM/dd/yyyy", true),
      ("MM/dd/yyyy HH:mm", false),
      ("dd-MM-yy", true),
      ("dd-MM-yyyy", true),
    ]
    return formats.map { format, dateOnly in
      let formatter = DateFormatter()
      formatter.locale = Locale(identifier: "en_US_POSIX")
      formatter.timeZone = TimeZone.current
      formatter.dateFormat = format
      return (formatter, dateOnly)
    }
  }
}
