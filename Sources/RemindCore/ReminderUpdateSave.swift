import Foundation

enum ReminderUpdateSave {
  static func save(isMoving: Bool, using save: () throws -> Void) throws {
    do {
      try save()
    } catch {
      let failure = error as NSError
      guard isMoving, failure.domain == "com.apple.reminderkit", failure.code == -3002 else {
        throw error
      }
      throw RemindCoreError.operationFailed(
        "Unable to move reminder between lists: EventKit rejected the move (com.apple.reminderkit error -3002). "
          + "Moves involving shared lists may not be supported. Move the reminder in Reminders.app, "
          + "then retry any other edits."
      )
    }
  }
}
