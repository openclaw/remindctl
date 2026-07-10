import EventKit
import Foundation

private struct ReminderAlarmReplacement {
  let alarmsToRemove: [EKAlarm]
  let alarmToAdd: EKAlarm?
}

enum ReminderAlarmMutation {
  static func replaceDateAlarms(on reminder: EKReminder, with date: Date?) {
    let replacement = replacingDateAlarms(in: reminder.alarms ?? [], with: date)
    for alarm in replacement.alarmsToRemove {
      reminder.removeAlarm(alarm)
    }
    if let alarm = replacement.alarmToAdd {
      reminder.addAlarm(alarm)
    }
  }

  private static func replacingDateAlarms(in alarms: [EKAlarm], with date: Date?) -> ReminderAlarmReplacement {
    ReminderAlarmReplacement(
      alarmsToRemove: alarms.filter { $0.structuredLocation == nil && $0.absoluteDate != nil },
      alarmToAdd: date.map(EKAlarm.init(absoluteDate:))
    )
  }
}
