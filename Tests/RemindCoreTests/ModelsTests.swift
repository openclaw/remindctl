import Foundation
import Testing

@testable import RemindCore

@MainActor
struct ModelsTests {
  @Test("Recurrence rule display strings")
  func recurrenceDisplayStrings() {
    #expect(RecurrenceRule(frequency: .daily).displayString == "daily")
    #expect(RecurrenceRule(frequency: .weekly, interval: 2).displayString == "every 2 weeks")
    #expect(RecurrenceRule(frequency: .monthly, interval: 3).displayString == "every 3 months")
    #expect(RecurrenceRule(frequency: .yearly, interval: 4).displayString == "every 4 years")
  }

  @Test("Reminder draft and update carry the url field")
  func urlField() {
    let url = URL(string: "https://example.com/product")!

    // Draft: explicit url is preserved; default is nil.
    let draft = ReminderDraft(title: "Buy", notes: nil, url: url, dueDate: nil, priority: .none)
    #expect(draft.url == url)
    #expect(ReminderDraft(title: "Buy", notes: nil, dueDate: nil, priority: .none).url == nil)

    // Update double-optional: nil = leave, .some(nil) = clear, .some(url) = set.
    #expect(ReminderUpdate(title: "x").url == nil)
    let setUpdate = ReminderUpdate(url: .some(url))
    #expect(setUpdate.url! == url)
    let clearUpdate = ReminderUpdate(url: .some(nil))
    #expect(clearUpdate.url != nil)
    #expect(clearUpdate.url! == nil)
  }

  @Test("Model initializers preserve defaults and explicit values")
  func initializerDefaults() {
    let date = Date(timeIntervalSince1970: 1_700_000_000)
    let parsed = ParsedUserDate(date: date, isDateOnly: true)
    let location = LocationTrigger(address: "Home")
    #expect(location.address == "Home")
    #expect(location.latitude == nil)
    #expect(location.longitude == nil)
    #expect(location.radius == 100)
    #expect(location.proximity == .arriving)

    let leaving = LocationTrigger(address: "Office", latitude: 1, longitude: 2, radius: 250, proximity: .leaving)
    #expect(leaving.latitude == 1)
    #expect(leaving.longitude == 2)
    #expect(leaving.radius == 250)
    #expect(leaving.proximity == .leaving)

    let draft = ReminderDraft(
      title: "Draft",
      notes: "Notes",
      dueDate: parsed,
      recurrenceRule: RecurrenceRule(frequency: .daily),
      locationTrigger: location,
      priority: .high
    )
    #expect(draft.title == "Draft")
    #expect(draft.notes == "Notes")
    #expect(draft.dueDate == parsed)
    #expect(draft.alarmDate == nil)
    #expect(draft.recurrenceRule == RecurrenceRule(frequency: .daily))
    #expect(draft.locationTrigger == location)
    #expect(draft.priority == .high)

    let update = ReminderUpdate(
      title: "Updated",
      notes: nil,
      dueDate: .some(nil),
      alarmDate: .some(parsed),
      recurrenceRule: .some(nil),
      priority: .low,
      listTarget: .id("LIST"),
      isCompleted: true
    )
    #expect(update.title == "Updated")
    #expect(update.notes == nil)
    #expect(update.dueDate! == nil)
    #expect(update.alarmDate! == parsed)
    #expect(update.recurrenceRule! == nil)
    #expect(update.priority == .low)
    #expect(update.listName == nil)
    #expect(update.listTarget == .id("LIST"))
    #expect(update.isCompleted == true)
  }

  @Test("Reminder item default metadata fields")
  func reminderItemDefaults() {
    let item = ReminderItem(
      id: "REM",
      title: "Title",
      notes: nil,
      isCompleted: false,
      completionDate: nil,
      priority: .none,
      dueDate: nil,
      listID: "LIST",
      listName: "Inbox"
    )
    #expect(item.id == "REM")
    #expect(item.title == "Title")
    #expect(item.url == nil)
    #expect(!item.isCompleted)
    #expect(item.creationDate == nil)
    #expect(item.lastModifiedDate == nil)
    #expect(item.dueDateIsAllDay == false)
    #expect(item.alarmDate == nil)
    #expect(item.recurrenceRule == nil)
    #expect(item.locationTrigger == nil)
    #expect(item.listID == "LIST")
    #expect(item.listName == "Inbox")
  }
}
