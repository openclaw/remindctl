import Testing

@testable import remindctl

struct CommandRouterTests {
  @Test("Surplus command arguments are rejected")
  func surplusArguments() async {
    let code = await CommandRouter().run(argv: ["remindctl", "completion", "bash", "unexpected"])
    #expect(code == 1)
  }

  @Test("Bulk commands preserve all positional values", arguments: ["list", "complete", "delete"])
  func bulkArguments(_ command: String) throws {
    let invocation = try CommandRouter().program.resolve(arguments: [
      "remindctl", command, "First", "Second", "--plain",
    ])
    #expect(invocation.parsedValues.positional == ["First", "Second"])
    #expect(invocation.parsedValues.flags.contains("plainOutput"))
  }

  @Test(
    "Single-target commands reject extra positionals", arguments: ["add", "edit", "search", "info", "link", "open"])
  func singleTargetArguments(_ command: String) {
    #expect(throws: (any Error).self) {
      try CommandRouter().program.resolve(arguments: ["remindctl", command, "First", "Second"])
    }
  }

  @Test("A renamed executable resolves the canonical command")
  func renamedExecutable() async {
    let code = await CommandRouter().run(argv: ["/tmp/custom-reminders", "completion", "bash"])
    #expect(code == 0)
  }

  @Test("Help and version after the terminator are data", arguments: ["--help", "-h", "--version", "-V"])
  func literalControlArguments(_ value: String) async {
    let code = await CommandRouter().run(argv: ["remindctl", "completion", "--", value])
    #expect(code == 1)
  }

  @Test("Help and version before the terminator remain controls", arguments: ["--help", "--version"])
  func controlArguments(_ value: String) async {
    let code = await CommandRouter().run(argv: ["remindctl", "completion", value, "--", "unsupported"])
    #expect(code == 0)
  }
}
