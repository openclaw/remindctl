import RemindCore
import Testing

@testable import remindctl

struct ListActionTests {
  private func action(_ arguments: [String]) throws -> ListCommand.Action {
    let values = try CommandRouter().program.resolve(argv: ["remindctl", "list"] + arguments).parsedValues
    return try ListCommand.action(
      names: values.positional,
      listID: values.option("listID"),
      create: values.flag("create"),
      delete: values.flag("delete"),
      renameTo: values.option("rename"))
  }

  @Test(
    "Conflicting list mutations are rejected",
    arguments: [
      ["--create", "--delete"], ["--create", "--rename", "New"],
      ["--delete", "--rename", "New"], ["--create", "--delete", "--rename", "New"],
    ])
  func conflictingMutations(_ flags: [String]) {
    #expect(throws: RemindCoreError.operationFailed("Use only one of --create, --delete, or --rename")) {
      try action(["Synthetic"] + flags)
    }
  }

  @Test("Mutations require a target", arguments: [["--create"], ["--delete"], ["--rename", "New"]])
  func missingTarget(_ flags: [String]) {
    #expect(throws: ParsedValuesError.self) {
      try action(flags)
    }
  }

  @Test("Valid list reads and mutations retain their action")
  func validActions() throws {
    #expect(try action([]) == .show)
    #expect(try action(["First", "Second"]) == .show)
    #expect(try action(["Synthetic", "--create"]) == .create)
    #expect(try action(["Synthetic", "--rename", "New"]) == .rename("New"))
    #expect(try action(["--list-id", "abcd", "--delete"]) == .delete)
    #expect(throws: RemindCoreError.self) {
      try action(["First", "Second", "--delete"])
    }
    #expect(throws: RemindCoreError.self) {
      try action(["--list-id", "abcd", "--create"])
    }
  }
}
