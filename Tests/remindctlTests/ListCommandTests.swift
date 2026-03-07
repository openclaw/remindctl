import Foundation
import Testing

@testable import RemindCore
@testable import remindctl

@MainActor
struct ListCommandTests {
  @Test("Requested list names preserve order and trim whitespace")
  func requestedListNamesPreserveOrder() {
    let names = ListCommand.requestedListNames(from: ["  Grocery Store  ", "COSTCO", " Personal "])
    #expect(names == ["Grocery Store", "COSTCO", "Personal"])
  }

  @Test("Requested list names drop empty inputs")
  func requestedListNamesDropEmptyInputs() {
    let names = ListCommand.requestedListNames(from: ["", "  ", "\n", "Work"])
    #expect(names == ["Work"])
  }

  @Test("Management actions reject multiple list names")
  func managementActionsRejectMultipleNames() {
    #expect(throws: RemindCoreError.operationFailed("--rename requires exactly one list name")) {
      try ListCommand.validateSingleTargetAction(
        listNames: ["Work", "Personal"],
        renameTo: "Office",
        delete: false,
        create: false
      )
    }

    #expect(throws: RemindCoreError.operationFailed("--delete requires exactly one list name")) {
      try ListCommand.validateSingleTargetAction(
        listNames: ["Work", "Personal"],
        renameTo: nil,
        delete: true,
        create: false
      )
    }

    #expect(throws: RemindCoreError.operationFailed("--create requires exactly one list name")) {
      try ListCommand.validateSingleTargetAction(
        listNames: ["Work", "Personal"],
        renameTo: nil,
        delete: false,
        create: true
      )
    }
  }

  @Test("Reminder groups merge by id and preserve first-seen order")
  func mergeReminderGroupsPreservesFirstSeenOrder() {
    let work = [
      makeReminder(id: "1", title: "Alpha", listID: "work", listName: "Work"),
      makeReminder(id: "2", title: "Beta", listID: "work", listName: "Work"),
    ]
    let personal = [
      makeReminder(id: "2", title: "Beta duplicate", listID: "personal", listName: "Personal"),
      makeReminder(id: "3", title: "Gamma", listID: "personal", listName: "Personal"),
    ]

    let merged = ListCommand.mergeReminderGroups([work, personal])

    #expect(merged.map(\.id) == ["1", "2", "3"])
    #expect(merged.map(\.title) == ["Alpha", "Beta", "Gamma"])
  }

  @Test("Repeated list groups do not duplicate reminders")
  func repeatedListGroupsDoNotDuplicateOutput() {
    let groceries = [
      makeReminder(id: "1", title: "Milk", listID: "groceries", listName: "Groceries"),
      makeReminder(id: "2", title: "Eggs", listID: "groceries", listName: "Groceries"),
    ]

    let merged = ListCommand.mergeReminderGroups([groceries, groceries])

    #expect(merged.map(\.id) == ["1", "2"])
  }

  @Test("List help includes multi-list example")
  func listHelpIncludesMultiListExample() {
    #expect(ListCommand.spec.discussion?.contains("one or more names") == true)
    #expect(ListCommand.spec.usageExamples.contains("remindctl list Work Personal"))
  }

  private func makeReminder(id: String, title: String, listID: String, listName: String) -> ReminderItem {
    ReminderItem(
      id: id,
      title: title,
      notes: nil,
      isCompleted: false,
      completionDate: nil,
      priority: .none,
      dueDate: nil,
      listID: listID,
      listName: listName
    )
  }
}
