import Commander
import Foundation
import RemindCore

enum DeleteCommand {
  static var spec: CommandSpec {
    CommandSpec(
      name: "delete",
      abstract: "Delete reminders",
      discussion: "Use indexes or ID prefixes from show output.",
      signature: CommandSignatures.withRuntimeFlags(
        CommandSignature(
          arguments: [
            .make(label: "ids", help: "Indexes or ID prefixes", isOptional: true)
          ],
          flags: [
            .make(label: "dryRun", names: [.short("n"), .long("dry-run")], help: "Preview without changes"),
            .make(label: "force", names: [.short("f"), .long("force")], help: "Skip confirmation"),
          ]
        )
      ),
      usageExamples: [
        "remindctl delete 1",
        "remindctl delete 4A83",
        "remindctl delete 1 2 3 --force",
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

      if !values.flag("force") && !runtime.noInput && Console.isTTY {
        let prompt = "Delete \(resolved.count) reminder(s)?"
        if !Console.confirm(prompt, defaultValue: false) {
          return
        }
      }

      let count = try await store.deleteReminders(ids: resolved.map { $0.id })
      OutputRenderer.printDeleteResult(count, format: runtime.outputFormat)
    }
  }
}
