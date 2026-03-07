import Commander
import Foundation
import RemindCore

enum ListCommand {
  static var spec: CommandSpec {
    CommandSpec(
      name: "list",
      abstract: "List reminder lists or show list contents",
      discussion: "Without a name, shows all lists. With one or more names, shows reminders in those lists. Management actions remain single-list only.",
      signature: CommandSignatures.withRuntimeFlags(
        CommandSignature(
          arguments: [
            .make(label: "name", help: "List name", isOptional: true)
          ],
          options: [
            .make(
              label: "rename",
              names: [.short("r"), .long("rename")],
              help: "Rename the list",
              parsing: .singleValue
            )
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
        "remindctl list Work Personal",
        "remindctl list Work --rename Office",
        "remindctl list Work --delete",
        "remindctl list Projects --create",
      ]
    ) { values, runtime in
      let listNames = requestedListNames(from: values.positional)
      let renameTo = values.option("rename")
      let deleteList = values.flag("delete")
      let createList = values.flag("create")
      let force = values.flag("force")
      try validateSingleTargetAction(
        listNames: listNames,
        renameTo: renameTo,
        delete: deleteList,
        create: createList
      )

      let store = RemindersStore()
      try await store.requestAccess()

      if let name = listNames.first {
        if deleteList {
          if !force && !runtime.noInput && Console.isTTY {
            if !Console.confirm("Delete list \"\(name)\"?", defaultValue: false) {
              return
            }
          }
          try await store.deleteList(name: name)
          if runtime.outputFormat == .standard {
            Swift.print("Deleted list \"\(name)\"")
          }
          return
        }

        if let renameTo {
          try await store.renameList(oldName: name, newName: renameTo)
          if runtime.outputFormat == .standard {
            Swift.print("Renamed list \"\(name)\" -> \"\(renameTo)\"")
          }
          return
        }

        if createList {
          let list = try await store.createList(name: name)
          if runtime.outputFormat == .json {
            OutputRenderer.printLists(
              [ListSummary(id: list.id, title: list.title, reminderCount: 0, overdueCount: 0)],
              format: runtime.outputFormat
            )
          } else if runtime.outputFormat == .standard {
            Swift.print("Created list \"\(list.title)\"")
          }
          return
        }

        if listNames.count == 1 {
          let reminders = try await store.reminders(in: name)
          OutputRenderer.printReminders(reminders, format: runtime.outputFormat)
          return
        }

        var reminderGroups: [[ReminderItem]] = []
        reminderGroups.reserveCapacity(listNames.count)
        for listName in listNames {
          reminderGroups.append(try await store.reminders(in: listName))
        }
        let reminders = mergeReminderGroups(reminderGroups)
        OutputRenderer.printReminders(reminders, format: runtime.outputFormat)
        return
      }

      let lists = await store.lists()
      let reminders = try await store.reminders(in: nil)

      let startOfToday = Calendar.current.startOfDay(for: Date())
      var counts: [String: (total: Int, overdue: Int)] = [:]
      for reminder in reminders where !reminder.isCompleted {
        let entry = counts[reminder.listID] ?? (0, 0)
        let overdue = (reminder.dueDate.map { $0 < startOfToday } ?? false) ? 1 : 0
        counts[reminder.listID] = (entry.total + 1, entry.overdue + overdue)
      }

      let summaries = lists.map { list in
        let entry = counts[list.id] ?? (0, 0)
        return ListSummary(
          id: list.id,
          title: list.title,
          reminderCount: entry.total,
          overdueCount: entry.overdue
        )
      }

      OutputRenderer.printLists(summaries, format: runtime.outputFormat)
    }
  }

  static func requestedListNames(from positional: [String]) -> [String] {
    positional.compactMap { rawName in
      let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
      return name.isEmpty ? nil : name
    }
  }

  static func validateSingleTargetAction(
    listNames: [String],
    renameTo: String?,
    delete: Bool,
    create: Bool
  ) throws {
    guard listNames.count > 1 else { return }

    if renameTo != nil {
      throw RemindCoreError.operationFailed("--rename requires exactly one list name")
    }
    if delete {
      throw RemindCoreError.operationFailed("--delete requires exactly one list name")
    }
    if create {
      throw RemindCoreError.operationFailed("--create requires exactly one list name")
    }
  }

  static func mergeReminderGroups(_ groups: [[ReminderItem]]) -> [ReminderItem] {
    var merged: [ReminderItem] = []
    var seenIDs = Set<String>()

    for group in groups {
      for reminder in group where seenIDs.insert(reminder.id).inserted {
        merged.append(reminder)
      }
    }

    return merged
  }
}
