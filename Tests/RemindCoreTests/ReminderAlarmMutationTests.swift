import EventKit
import Foundation
import Testing

@testable import RemindCore

@MainActor
struct ReminderAlarmMutationTests {
  @Test("Replacing an absolute alarm preserves relative and geofence alarms")
  func replaceAbsoluteAlarmPreservesIndependentAlarms() {
    let oldDate = Date(timeIntervalSince1970: 1_700_000_000)
    let newDate = Date(timeIntervalSince1970: 1_700_000_600)
    let timedAlarm = EKAlarm(absoluteDate: oldDate)
    let geofenceAlarm = locationAlarm()
    let relativeAlarm = EKAlarm(relativeOffset: -300)
    let reminder = EKReminder(eventStore: EKEventStore())
    reminder.addAlarm(timedAlarm)
    reminder.addAlarm(geofenceAlarm)
    reminder.addAlarm(relativeAlarm)

    ReminderAlarmMutation.replaceDateAlarms(on: reminder, with: newDate)

    let alarms = reminder.alarms ?? []
    #expect(alarms.count == 3)
    #expect(alarms.compactMap(\.absoluteDate) == [newDate])
    #expect(alarms.compactMap(\.structuredLocation?.title) == ["Home"])
    #expect(alarms.filter { $0.absoluteDate == nil && $0.structuredLocation == nil }.map(\.relativeOffset) == [-300])
  }

  @Test("Clearing an absolute alarm preserves relative and geofence alarms")
  func clearAbsoluteAlarmPreservesIndependentAlarms() {
    let timedAlarm = EKAlarm(absoluteDate: Date(timeIntervalSince1970: 1_700_000_000))
    let geofenceAlarm = locationAlarm()
    let relativeAlarm = EKAlarm(relativeOffset: -300)
    let reminder = EKReminder(eventStore: EKEventStore())
    reminder.addAlarm(timedAlarm)
    reminder.addAlarm(geofenceAlarm)
    reminder.addAlarm(relativeAlarm)

    ReminderAlarmMutation.replaceDateAlarms(on: reminder, with: nil)

    let alarms = reminder.alarms ?? []
    #expect(alarms.count == 2)
    #expect(alarms.compactMap(\.absoluteDate).isEmpty)
    #expect(alarms.compactMap(\.structuredLocation?.title) == ["Home"])
    #expect(alarms.filter { $0.absoluteDate == nil && $0.structuredLocation == nil }.map(\.relativeOffset) == [-300])
  }

  private func locationAlarm() -> EKAlarm {
    let alarm = EKAlarm()
    alarm.structuredLocation = EKStructuredLocation(title: "Home")
    alarm.proximity = .enter
    return alarm
  }
}
