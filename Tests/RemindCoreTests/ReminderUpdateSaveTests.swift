import Foundation
import Testing

@testable import RemindCore

struct ReminderUpdateSaveTests {
  @Test("A rejected list move explains the shared-list limitation")
  func rejectedMove() {
    let error = NSError(domain: "com.apple.reminderkit", code: -3002)
    #expect(throws: RemindCoreError.operationFailed(
      "Unable to move reminder between lists: EventKit rejected the move (com.apple.reminderkit error -3002). "
        + "Moves involving shared lists may not be supported. Move the reminder in Reminders.app, "
        + "then retry any other edits."
    )) {
      try ReminderUpdateSave.save(isMoving: true) { throw error }
    }
  }

  @Test("Unrelated save errors are preserved", arguments: [
    (false, "com.apple.reminderkit", -3002),
    (true, "OtherDomain", -3002),
    (true, "com.apple.reminderkit", -3001),
  ])
  func unrelatedErrors(input: (Bool, String, Int)) {
    let (isMoving, domain, code) = input
    let original = NSError(domain: domain, code: code, userInfo: [NSLocalizedDescriptionKey: "Original failure"])
    do {
      try ReminderUpdateSave.save(isMoving: isMoving) { throw original }
      Issue.record("Expected the original save failure")
    } catch {
      #expect(error as NSError === original)
    }
  }

  @Test("Successful saves run exactly once", arguments: [true, false])
  func successfulSave(isMoving: Bool) throws {
    var calls = 0
    try ReminderUpdateSave.save(isMoving: isMoving) { calls += 1 }
    #expect(calls == 1)
  }
}
