import Foundation
import Testing

@testable import RemindCore

@MainActor
struct DateParsingTests {
  private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
    return calendar
  }()

  @Test("Relative date parsing")
  func relativeDates() {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let today = DateParsing.parseUserDate("today", now: now, calendar: calendar)
    let tomorrow = DateParsing.parseUserDate("tomorrow", now: now, calendar: calendar)
    let yesterday = DateParsing.parseUserDate("yesterday", now: now, calendar: calendar)

    #expect(today == calendar.startOfDay(for: now))
    #expect(tomorrow == calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)))
    #expect(yesterday == calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now)))
  }

  @Test("ISO 8601 parsing")
  func isoParsing() {
    let input = "2026-01-03T12:34:56Z"
    let parsed = DateParsing.parseUserDate(input)
    #expect(parsed != nil)
  }

  @Test("Local ISO 8601 without timezone parsing")
  func localISOParsing() {
    let input = "2026-01-03T12:34:56"
    let parsed = DateParsing.parseUserDateWithMetadata(input)
    #expect(parsed != nil)
    #expect(parsed?.isDateOnly == false)
  }

  @Test("Local dates honor the supplied time zone", arguments: [14 * 3600, -10 * 3600])
  func suppliedTimeZone(_ offset: Int) throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(secondsFromGMT: offset))
    let expected = try #require(
      calendar.date(from: DateComponents(year: 2026, month: 1, day: 3, hour: 12, minute: 34)))

    for input in ["2026-01-03T12:34", "2026-01-03 12:34", "01/03/2026 12:34"] {
      let parsed = try #require(DateParsing.parseUserDateWithMetadata(input, calendar: calendar))
      #expect(parsed.date == expected)
      #expect(!parsed.isDateOnly)
    }
    let allDay = try #require(DateParsing.parseUserDateWithMetadata("2026-01-03", calendar: calendar))
    #expect(allDay.date == calendar.startOfDay(for: expected))
    #expect(allDay.isDateOnly)

    let absolute = "2026-01-03T12:34:00Z"
    #expect(DateParsing.parseUserDate(absolute, calendar: calendar) == ISO8601DateFormatter().date(from: absolute))
  }

  @Test("Formatted date parsing")
  func formattedParsing() {
    let input = "2026-01-03 10:30"
    let parsed = DateParsing.parseUserDate(input)
    #expect(parsed != nil)
  }

  @Test(
    "Reject malformed absolute dates",
    arguments: [
      "2026-02-30T12:00:00Z", "2025-02-29T12:00:00.123Z",
      "2026-04-31T12:00:00+02:00", "2026-01-03T12:00:00Zjunk",
      "2026-01-03T12:00:00+99:00", "2026-01-03T12:00:00+01:99",
      "2026-01-03T25:00:00Z", "2026-01-03T12:60:00Z",
      "2026-02-30", "2026-13-01", "2026-01-03junk",
    ])
  func rejectMalformedAbsoluteDates(_ input: String) {
    #expect(DateParsing.parseUserDate(input, calendar: calendar) == nil)
    #expect(ReminderFiltering.parse(input, calendar: calendar) == nil)
  }

  @Test(
    "Date formats do not steal each other's inputs",
    arguments: [
      "2026-01-03", "01/03/2026", "03-01-26", "03-01-2026",
    ])
  func disambiguateDateFormats(_ input: String) throws {
    let parsed = try #require(DateParsing.parseUserDateWithMetadata(input, calendar: calendar))
    #expect(parsed.date == calendar.date(from: DateComponents(year: 2026, month: 1, day: 3)))
    #expect(parsed.isDateOnly)
  }

  @Test(
    "Preserve unambiguous legacy date spellings",
    arguments: [
      "2026-1-3", "2026/1/3", "2026.1.3", "1/3/2026",
    ])
  func legacyDateSpellings(_ input: String) throws {
    let parsed = try #require(DateParsing.parseUserDateWithMetadata(input, calendar: calendar))
    #expect(parsed.date == calendar.date(from: DateComponents(year: 2026, month: 1, day: 3)))
    #expect(parsed.isDateOnly)
  }

  @Test(
    "Preserve unpadded times and whitespace",
    arguments: [
      "2026-01-03 9:05", "2026-01-03 9:5", "2026-1-3T9:5", "2026-01-03   09:05",
    ])
  func legacyTimeSpellings(_ input: String) throws {
    let parsed = try #require(DateParsing.parseUserDateWithMetadata(input, calendar: calendar))
    #expect(parsed.date == calendar.date(from: DateComponents(year: 2026, month: 1, day: 3, hour: 9, minute: 5)))
    #expect(!parsed.isDateOnly)
  }

  @Test(
    "Valid ISO offsets and fractions survive strict validation",
    arguments: [
      "2024-02-29T12:34:56Z", "2024-02-29T12:34:56.123456Z",
      "2024-02-29T14:34:56+02:00", "2024-02-29T02:34:56-1000",
      "2024-02-29t12:34:56z",
      "2024-2-29T2:34:56-1000",
    ])
  func validAbsoluteDates(_ input: String) throws {
    let parsed = try #require(DateParsing.parseUserDateWithMetadata(input, calendar: calendar))
    let expected = try #require(
      calendar.date(from: DateComponents(year: 2024, month: 2, day: 29, hour: 12, minute: 34, second: 56)))
    #expect(abs(parsed.date.timeIntervalSince(expected)) < 1)
    #expect(!parsed.isDateOnly)
  }

  @Test("Format display output")
  func displayFormatting() {
    let date = Date(timeIntervalSince1970: 1_700_000_000)
    let output = DateParsing.formatDisplay(date, calendar: calendar)
    #expect(output.isEmpty == false)
  }

  @Test("Date-only inputs carry metadata")
  func dateOnlyMetadata() {
    let now = Date(timeIntervalSince1970: 1_700_000_000)

    let today = DateParsing.parseUserDateWithMetadata("today", now: now, calendar: calendar)
    #expect(today?.date == calendar.startOfDay(for: now))
    #expect(today?.isDateOnly == true)

    let dateOnly = DateParsing.parseUserDateWithMetadata("2026-01-03")
    #expect(dateOnly?.isDateOnly == true)

    let dateTime = DateParsing.parseUserDateWithMetadata("2026-01-03 10:30")
    #expect(dateTime?.isDateOnly == false)
  }

  @Test("Display can omit time for all-day reminders")
  func displayFormattingDateOnly() {
    let date = Date(timeIntervalSince1970: 1_700_000_000)
    let timed = DateParsing.formatDisplay(date, calendar: calendar)
    let dateOnly = DateParsing.formatDisplay(date, isDateOnly: true, calendar: calendar)
    #expect(dateOnly.isEmpty == false)
    #expect(timed.count > dateOnly.count)
  }
}
