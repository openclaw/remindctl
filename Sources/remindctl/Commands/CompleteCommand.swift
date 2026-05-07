import Commander
import Foundation
import RemindCore

enum CompleteCommand {
  static var spec: CommandSpec {
    CommandSpec(
      name: "complete",
      abstract: "Mark reminders complete",
      discussion: "Use indexes or ID prefixes from show output.",
      signature: CommandSignatures.withRuntimeFlags(
        CommandSignature(
          arguments: [
            .make(label: "ids", help: "Indexes or ID prefixes", isOptional: true)
          ],
          flags: [
            .make(label: "dryRun", names: [.short("n"), .long("dry-run")], help: "Preview without changes")
          ]
        )
      ),
      usageExamples: [
        "remindctl complete 1",
        "remindctl complete 1 2 3",
        "remindctl complete 4A83",
      ]
    ) { values, runtime in
      let inputs = values.positional
      guard !inputs.isEmpty else {
        throw ParsedValuesError.missingArgument("ids")
      }

      let store = RemindersStore()
      try await store.requestAccess()
      let reminders = try await store.reminders(in: nil)
      let resolved = try IDResolver.resolve(inputs, from: reminders, indexedIDs: IndexCache.load())

      if values.flag("dryRun") {
        OutputRenderer.printReminders(resolved, format: runtime.outputFormat)
        return
      }

      let updated = try await store.completeReminders(ids: resolved.map { $0.id })
      OutputRenderer.printReminders(updated, format: runtime.outputFormat)
    }
  }
}
