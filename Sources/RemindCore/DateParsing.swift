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

    let absolute = trimmed.uppercased()
    for (pattern, format, isDateOnly) in absoluteFormats {
      // Select field order before parsing: DateFormatter can otherwise reinterpret day-first dates.
      guard absolute.range(of: "\\A\(pattern)\\z", options: .regularExpression) != nil else { continue }
      let formatter = DateFormatter()
      formatter.locale = Locale(identifier: "en_US_POSIX")
      formatter.calendar = Calendar(identifier: .gregorian)
      formatter.timeZone = calendar.timeZone
      formatter.dateFormat = format
      formatter.isLenient = false
      return formatter.date(from: absolute).map { ParsedUserDate(date: $0, isDateOnly: isDateOnly) }
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

  private static var absoluteFormats: [(pattern: String, format: String, isDateOnly: Bool)] {
    let date = "[0-9]{4}[-/.][0-9]{1,2}[-/.][0-9]{1,2}"
    let time = "(?:[01]?[0-9]|2[0-3]):[0-5]?[0-9]"
    let seconds = "\(time):[0-5]?[0-9]"
    let zone = "(?:Z|[+-](?:[01][0-9]|2[0-3]):?[0-5][0-9])"
    return [
      ("\(date)T\(seconds)\\.[0-9]+\(zone)", "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX", false),
      ("\(date)T\(seconds)\(zone)", "yyyy-MM-dd'T'HH:mm:ssXXXXX", false),
      ("\(date)T\(seconds)\\.[0-9]+", "yyyy-MM-dd'T'HH:mm:ss.SSSSSS", false),
      ("\(date)T\(seconds)", "yyyy-MM-dd'T'HH:mm:ss", false),
      ("\(date)T\(time)", "yyyy-MM-dd'T'HH:mm", false),
      (date, "yyyy-MM-dd", true),
      ("\(date) +\(time)", "yyyy-MM-dd HH:mm", false),
      ("\(date) +\(seconds)", "yyyy-MM-dd HH:mm:ss", false),
      ("[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}", "MM/dd/yyyy", true),
      ("[0-9]{1,2}/[0-9]{1,2}/[0-9]{4} +\(time)", "MM/dd/yyyy HH:mm", false),
      ("[0-9]{1,2}-[0-9]{1,2}-[0-9]{2}", "dd-MM-yy", true),
      ("[0-9]{1,2}-[0-9]{1,2}-[0-9]{4}", "dd-MM-yyyy", true),
    ]
  }
}
