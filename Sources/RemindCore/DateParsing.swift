import Foundation

public struct ParsedUserDate: Equatable, Sendable {
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
  ) -> Date? {
    parseUserDateWithMetadata(input, now: now, calendar: calendar)?.date
  }

  /// Interprets local dates in the supplied calendar's time zone; explicit ISO offsets take precedence.
  public static func parseUserDateWithMetadata(
    _ input: String,
    now: Date = Date(),
    calendar: Calendar = .current
  ) -> ParsedUserDate? {
    let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
    let lower = trimmed.lowercased()

    if let relative = parseRelativeDate(lower, now: now, calendar: calendar) {
      return relative
    }

    let iso =
      isoFormatter(withFraction: true).date(from: trimmed)
      ?? isoFormatter(withFraction: false).date(from: trimmed)
    if let iso {
      return ParsedUserDate(date: iso, isDateOnly: false)
    }

    let localISO =
      localFormatter(format: "yyyy-MM-dd'T'HH:mm:ss.SSSSSS", calendar: calendar).date(from: trimmed)
      ?? localFormatter(format: "yyyy-MM-dd'T'HH:mm:ss.SSS", calendar: calendar).date(from: trimmed)
      ?? localFormatter(format: "yyyy-MM-dd'T'HH:mm:ss", calendar: calendar).date(from: trimmed)
      ?? localFormatter(format: "yyyy-MM-dd'T'HH:mm", calendar: calendar).date(from: trimmed)
    if let localISO {
      return ParsedUserDate(date: localISO, isDateOnly: false)
    }

    for (formatter, isDateOnly) in dateFormatters(calendar: calendar) {
      if let date = formatter.date(from: trimmed) {
        return ParsedUserDate(date: date, isDateOnly: isDateOnly)
      }
    }

    return nil
  }

  public static func formatDisplay(_ date: Date, isDateOnly: Bool = false, calendar: Calendar = .current) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale.current
    formatter.timeZone = calendar.timeZone
    formatter.dateStyle = .medium
    formatter.timeStyle = isDateOnly ? .none : .short
    return formatter.string(from: date)
  }

  private static func parseRelativeDate(_ input: String, now: Date, calendar: Calendar) -> ParsedUserDate? {
    switch input {
    case "today":
      return ParsedUserDate(date: calendar.startOfDay(for: now), isDateOnly: true)
    case "tomorrow":
      return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
        .map { ParsedUserDate(date: $0, isDateOnly: true) }
    case "yesterday":
      return calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now))
        .map { ParsedUserDate(date: $0, isDateOnly: true) }
    case "now":
      return ParsedUserDate(date: now, isDateOnly: false)
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

  private static func localFormatter(format: String, calendar: Calendar) -> DateFormatter {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = calendar.timeZone
    formatter.dateFormat = format
    return formatter
  }

  private static func dateFormatters(calendar: Calendar) -> [(DateFormatter, Bool)] {
    let formats: [(String, Bool)] = [
      ("yyyy-MM-dd", true),
      ("yyyy-MM-dd HH:mm", false),
      ("yyyy-MM-dd HH:mm:ss", false),
      ("MM/dd/yyyy", true),
      ("MM/dd/yyyy HH:mm", false),
      ("dd-MM-yy", true),
      ("dd-MM-yyyy", true),
    ]
    return formats.map { format, isDateOnly in
      (localFormatter(format: format, calendar: calendar), isDateOnly)
    }
  }
}
