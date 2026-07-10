import Testing

@testable import remindctl

struct EditCommandDateUpdateTests {
  @Test("Due-only edits do not request alarm mutation")
  func dueOnlyPreservesAlarms() throws {
    let updates = try EditCommand.parsedDateUpdates(
      dueValue: "2026-07-10 09:00", clearDue: false, alarmValue: nil, clearAlarm: false)

    #expect(updates.dueDate != nil)
    #expect(updates.dueDate!!.isDateOnly == false)
    #expect(updates.alarmDate == nil)
  }

  @Test("Clear-due-only edits do not request alarm mutation")
  func clearDueOnlyPreservesAlarms() throws {
    let updates = try EditCommand.parsedDateUpdates(
      dueValue: nil, clearDue: true, alarmValue: nil, clearAlarm: false)

    #expect(updates.dueDate != nil)
    #expect(updates.dueDate! == nil)
    #expect(updates.alarmDate == nil)
  }

  @Test("Due and alarm can be changed together explicitly")
  func dueAndAlarmAreIndependent() throws {
    let updates = try EditCommand.parsedDateUpdates(
      dueValue: "2026-07-10", clearDue: false, alarmValue: "2026-07-10 08:55", clearAlarm: false)

    #expect(updates.dueDate != nil)
    #expect(updates.dueDate!!.isDateOnly)
    #expect(updates.alarmDate != nil)
    #expect(updates.alarmDate!!.isDateOnly == false)
  }

  @Test("Due can change while an absolute alarm is explicitly cleared")
  func dueAndClearAlarmAreIndependent() throws {
    let updates = try EditCommand.parsedDateUpdates(
      dueValue: "2026-07-10", clearDue: false, alarmValue: nil, clearAlarm: true)

    #expect(updates.dueDate != nil)
    #expect(updates.alarmDate != nil)
    #expect(updates.alarmDate! == nil)
  }

  @Test("Due and absolute alarm can be cleared together explicitly")
  func clearDueAndClearAlarmAreIndependent() throws {
    let updates = try EditCommand.parsedDateUpdates(
      dueValue: nil, clearDue: true, alarmValue: nil, clearAlarm: true)

    #expect(updates.dueDate != nil)
    #expect(updates.dueDate! == nil)
    #expect(updates.alarmDate != nil)
    #expect(updates.alarmDate! == nil)
  }

  @Test("Due and alarm flags reject conflicting set and clear combinations")
  func conflictsAreRejected() {
    #expect(throws: Error.self) {
      _ = try EditCommand.parsedDateUpdates(
        dueValue: "2026-07-10", clearDue: true, alarmValue: nil, clearAlarm: false)
    }
    #expect(throws: Error.self) {
      _ = try EditCommand.parsedDateUpdates(
        dueValue: nil, clearDue: false, alarmValue: "2026-07-10 08:55", clearAlarm: true)
    }
  }
}
