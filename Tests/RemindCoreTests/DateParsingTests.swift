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

    #expect(today?.date == calendar.startOfDay(for: now))
    #expect(tomorrow?.date == calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)))
    #expect(yesterday?.date == calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now)))
  }

  @Test("ISO 8601 parsing")
  func isoParsing() {
    let input = "2026-01-03T12:34:56Z"
    let parsed = DateParsing.parseUserDate(input)
    #expect(parsed != nil)
  }

  @Test("Formatted date parsing")
  func formattedParsing() {
    let input = "2026-01-03 10:30"
    let parsed = DateParsing.parseUserDate(input)
    #expect(parsed != nil)
  }

  @Test("Format display output")
  func displayFormatting() {
    let date = Date(timeIntervalSince1970: 1_700_000_000)
    let output = DateParsing.formatDisplay(date, calendar: calendar)
    #expect(output.isEmpty == false)
  }

  @Test("Date-only inputs return isDateOnly true")
  func dateOnlyInputs() {
    let now = Date(timeIntervalSince1970: 1_700_000_000)

    let today = DateParsing.parseUserDate("today", now: now, calendar: calendar)
    #expect(today?.isDateOnly == true)

    let tomorrow = DateParsing.parseUserDate("tomorrow", now: now, calendar: calendar)
    #expect(tomorrow?.isDateOnly == true)

    let yesterday = DateParsing.parseUserDate("yesterday", now: now, calendar: calendar)
    #expect(yesterday?.isDateOnly == true)

    let dateOnly = DateParsing.parseUserDate("2026-01-03")
    #expect(dateOnly?.isDateOnly == true)

    let slashDate = DateParsing.parseUserDate("01/03/2026")
    #expect(slashDate?.isDateOnly == true)
  }

  @Test("Date+time inputs return isDateOnly false")
  func dateTimeInputs() {
    let now = Date(timeIntervalSince1970: 1_700_000_000)

    let nowResult = DateParsing.parseUserDate("now", now: now, calendar: calendar)
    #expect(nowResult?.isDateOnly == false)

    let iso = DateParsing.parseUserDate("2026-01-03T12:34:56Z")
    #expect(iso?.isDateOnly == false)

    let dateTime = DateParsing.parseUserDate("2026-01-03 10:30")
    #expect(dateTime?.isDateOnly == false)

    let dateTimeSec = DateParsing.parseUserDate("2026-01-03 10:30:00")
    #expect(dateTimeSec?.isDateOnly == false)
  }

  @Test("formatDisplay omits time when isDateOnly is true")
  func displayFormattingDateOnly() {
    let date = Date(timeIntervalSince1970: 1_700_000_000)
    let withTime = DateParsing.formatDisplay(date, calendar: calendar)
    let withoutTime = DateParsing.formatDisplay(date, isDateOnly: true, calendar: calendar)

    #expect(withTime.count > withoutTime.count)
    #expect(withoutTime.isEmpty == false)
  }
}
