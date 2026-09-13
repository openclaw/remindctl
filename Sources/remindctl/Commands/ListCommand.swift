import Commander
import Foundation
import RemindCore

enum ListCommand {
  enum Action: Equatable {
    case show
    case create
    case delete
    case rename(String)
  }

  static var spec: CommandSpec {
    CommandSpec(
      name: "list",
      abstract: "List reminder lists or show list contents",
      discussion: "Without a name, shows all lists. With one or more names, shows reminders in those lists.",
      signature: CommandSignatures.withRuntimeFlags(
        CommandSignature(
          arguments: [
            .make(label: "name", help: "List name(s)", isOptional: true)
          ],
          options: [
            .make(
              label: "listID",
              names: [.long("list-id")],
              help: "Target a list by ID or ID prefix",
              parsing: .singleValue
            ),
            .make(
              label: "rename",
              names: [.short("r"), .long("rename")],
              help: "Rename the list",
              parsing: .singleValue
            ),
          ],
          flags: [
            .make(label: "delete", names: [.short("d"), .long("delete")], help: "Delete the list"),
            .make(label: "create", names: [.long("create")], help: "Create list if missing"),
            .make(label: "force", names: [.short("f"), .long("force")], help: "Skip confirmation prompts"),
          ]
        )
      ),
      usageExamples: [
        "remindctl list",
        "remindctl list Work",
        "remindctl list Work Errands",
        "remindctl list Work --rename Office",
        "remindctl list Work --delete",
        "remindctl list Projects --create",
      ]
    ) { values, runtime in
      let names = values.positional
      let listID = values.option("listID")
      let action = try action(
        names: names,
        listID: listID,
        create: values.flag("create"),
        delete: values.flag("delete"),
        renameTo: values.option("rename"))
      let force = values.flag("force")

      let store = RemindersStore()
      try await store.requestAccess()

      if !names.isEmpty || listID != nil {
        let isMutation = action != .show
        if shouldReadMultipleLists(names: names, listID: listID, isMutation: isMutation) {
          let reminders = try await reminders(in: names, store: store)
          OutputRenderer.printReminders(reminders, format: runtime.outputFormat)
          return
        }

        let name = names.first
        let target = try CommandHelpers.listTarget(name: name, id: listID)
        if action == .delete {
          guard let target else {
            throw ParsedValuesError.missingArgument("name")
          }
          let title = try await store.resolveList(target).title
          if !force && !runtime.noInput && Console.isTTY {
            if !Console.confirm("Delete list \"\(title)\"?", defaultValue: false) {
              return
            }
          }
          try await store.deleteList(target: target)
          if runtime.outputFormat == .standard {
            Swift.print("Deleted list \"\(title)\"")
          }
          return
        }

        if case .rename(let renameTo) = action {
          guard let target else {
            throw ParsedValuesError.missingArgument("name")
          }
          let oldTitle = try await store.resolveList(target).title
          try await store.renameList(target: target, newName: renameTo)
          if runtime.outputFormat == .standard {
            Swift.print("Renamed list \"\(oldTitle)\" -> \"\(renameTo)\"")
          }
          return
        }

        if action == .create {
          guard let name else {
            throw ParsedValuesError.missingArgument("name")
          }
          let existing = try existingListForCreate(name: name, lists: await store.lists())
          let list: ReminderList
          let created: Bool
          if let existing {
            list = existing
            created = false
          } else {
            list = try await store.createList(name: name)
            created = true
          }
          if runtime.outputFormat == .json {
            let reminders = created ? [] : try await store.reminders(matching: .id(list.id))
            OutputRenderer.printLists(
              summaries(for: [list], reminders: reminders),
              format: runtime.outputFormat
            )
          } else if runtime.outputFormat == .standard {
            if created {
              Swift.print("Created list \"\(list.title)\"")
            } else {
              Swift.print("List \"\(list.title)\" already exists")
            }
          }
          return
        }

        let reminders =
          if let target {
            try await store.reminders(matching: target)
          } else {
            try await reminders(in: names, store: store)
          }
        OutputRenderer.printReminders(reminders, format: runtime.outputFormat)
        return
      }

      let lists = await store.lists()
      let reminders = try await store.reminders(in: nil)

      OutputRenderer.printLists(summaries(for: lists, reminders: reminders), format: runtime.outputFormat)
    }
  }

  static func action(
    names: [String], listID: String?, create: Bool, delete: Bool, renameTo: String?
  ) throws -> Action {
    var actions: [Action] = []
    if create { actions.append(.create) }
    if delete { actions.append(.delete) }
    if let renameTo { actions.append(.rename(renameTo)) }
    guard actions.count <= 1 else {
      throw RemindCoreError.operationFailed("Use only one of --create, --delete, or --rename")
    }
    guard let action = actions.first else { return .show }
    guard !names.isEmpty || listID != nil else {
      throw ParsedValuesError.missingArgument("name")
    }
    if !names.isEmpty {
      _ = try singleListName(names, forMutation: true)
    }
    if action == .create && listID != nil {
      throw RemindCoreError.operationFailed("Use a list name, not --list-id, with --create")
    }
    _ = try CommandHelpers.listTarget(name: names.first, id: listID)
    return action
  }

  static func summaries(
    for lists: [ReminderList],
    reminders: [ReminderItem],
    now: Date = Date(),
    calendar: Calendar = .current
  ) -> [ListSummary] {
    let startOfToday = calendar.startOfDay(for: now)
    var counts: [String: (total: Int, overdue: Int)] = [:]
    for reminder in reminders where !reminder.isCompleted {
      let entry = counts[reminder.listID] ?? (0, 0)
      let overdue = (reminder.dueDate.map { $0 < startOfToday } ?? false) ? 1 : 0
      counts[reminder.listID] = (entry.total + 1, entry.overdue + overdue)
    }

    return lists.map { list in
      let entry = counts[list.id] ?? (0, 0)
      return ListSummary(
        id: list.id,
        title: list.title,
        reminderCount: entry.total,
        overdueCount: entry.overdue
      )
    }
  }

  static func existingListForCreate(name: String, lists: [ReminderList]) throws -> ReminderList? {
    do {
      return try ListResolver.resolve(name, in: lists)
    } catch let error as RemindCoreError {
      guard case .listNotFound = error else {
        throw error
      }
      return nil
    }
  }

  static func singleListName(_ names: [String], forMutation: Bool) throws -> String {
    guard let name = names.first else {
      throw ParsedValuesError.missingArgument("name")
    }
    if forMutation && names.count > 1 {
      throw RemindCoreError.operationFailed("Only one list name can be used with create, delete, or rename")
    }
    return name
  }

  static func shouldReadMultipleLists(names: [String], listID: String?, isMutation: Bool) -> Bool {
    listID == nil && !isMutation && names.count > 1
  }

  private static func reminders(in names: [String], store: RemindersStore) async throws -> [ReminderItem] {
    var reminders: [ReminderItem] = []
    var seenNames = Set<String>()
    var seenReminderIDs = Set<String>()
    for name in names where seenNames.insert(name).inserted {
      for reminder in try await store.reminders(in: name) where seenReminderIDs.insert(reminder.id).inserted {
        reminders.append(reminder)
      }
    }
    return reminders
  }
}
