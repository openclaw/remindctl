extension RemindersStore {
  public func createReminder(_ draft: ReminderDraft, listName: String) async throws -> ReminderItem {
    try await createReminder(draft, target: .name(listName))
  }
}
