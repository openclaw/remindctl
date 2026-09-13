import Testing

@testable import remindctl

struct CommandRouterTests {
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
