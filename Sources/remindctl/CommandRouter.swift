import Commander
import Foundation
import RemindCore

struct CommandRouter {
  let rootName = "remindctl"
  let version: String
  let specs: [CommandSpec]
  let program: Program

  static let commandSpecs: [CommandSpec] = [
    ShowCommand.spec,
    ListCommand.spec,
    SearchCommand.spec,
    InfoCommand.spec,
    AddCommand.spec,
    EditCommand.spec,
    CompleteCommand.spec,
    DeleteCommand.spec,
    StatusCommand.spec,
    AuthorizeCommand.spec,
    DoctorCommand.spec,
    ExportCommand.spec,
    LinkCommand.spec,
    OpenCommand.spec,
    CompletionCommand.spec,
  ]

  init() {
    self.version = CommandRouter.resolveVersion()
    self.specs = Self.commandSpecs
    let descriptor = CommandDescriptor(
      name: rootName,
      abstract: "Manage Apple Reminders from the terminal",
      discussion: nil,
      signature: CommandSignature(),
      subcommands: specs.map { $0.descriptor },
      defaultSubcommandName: "show"
    )
    self.program = Program(descriptors: [descriptor])
  }

  func run() async -> Int32 {
    await run(argv: CommandLine.arguments)
  }

  func run(argv: [String]) async -> Int32 {
    var argv = applyAliases(argv)
    let controlArguments = argv.prefix { $0 != "--" }

    if controlArguments.contains("--version") || controlArguments.contains("-V") {
      Swift.print(version)
      return 0
    }

    if controlArguments.contains("--help") || controlArguments.contains("-h") {
      printHelp(for: argv)
      return 0
    }

    argv = rewriteImplicitShow(argv)

    do {
      let invocation = try program.resolve(arguments: [rootName] + argv.dropFirst())
      guard let commandName = invocation.path.last,
        let spec = specs.first(where: { $0.name == commandName })
      else {
        Console.printError("Unknown command")
        HelpPrinter.printRoot(version: version, rootName: rootName, commands: specs)
        return 1
      }
      let runtime = RuntimeOptions(parsedValues: invocation.parsedValues)
      do {
        try runtime.validate()
        try await spec.run(invocation.parsedValues, runtime)
        return 0
      } catch {
        Console.printError(error.localizedDescription)
        return 1
      }
    } catch let error as CommanderProgramError {
      Console.printError(error.description)
      if case .missingSubcommand = error {
        HelpPrinter.printRoot(version: version, rootName: rootName, commands: specs)
      }
      return 1
    } catch {
      Console.printError(error.localizedDescription)
      return 1
    }
  }

  private func applyAliases(_ argv: [String]) -> [String] {
    guard argv.count >= 2 else { return argv }
    var copy = argv
    if copy[1] == "lists" || copy[1] == "ls" {
      copy[1] = "list"
    }
    if copy[1] == "rm" {
      copy[1] = "delete"
    }
    if copy[1] == "done" {
      copy[1] = "complete"
    }
    return copy
  }

  private func rewriteImplicitShow(_ argv: [String]) -> [String] {
    guard argv.count >= 2 else { return argv }
    let token = argv[1]
    if token.hasPrefix("-") {
      return argv
    }

    let commandNames = Set(specs.map { $0.name })
    if commandNames.contains(token) {
      return argv
    }

    if ReminderFiltering.parse(token) != nil {
      var copy = argv
      copy.insert("show", at: 1)
      return copy
    }

    return argv
  }

  private func printHelp(for argv: [String]) {
    let path = helpPath(from: argv)
    if path.count <= 1 {
      HelpPrinter.printRoot(version: version, rootName: rootName, commands: specs)
      return
    }
    if let spec = specs.first(where: { $0.name == path[1] }) {
      HelpPrinter.printCommand(rootName: rootName, spec: spec)
    } else {
      HelpPrinter.printRoot(version: version, rootName: rootName, commands: specs)
    }
  }

  private func helpPath(from argv: [String]) -> [String] {
    var path: [String] = []
    for token in argv {
      if token == "--help" || token == "-h" { continue }
      if token.hasPrefix("-") { break }
      path.append(token)
    }
    return path
  }

  private static func resolveVersion() -> String {
    if let envVersion = ProcessInfo.processInfo.environment["REMINDCTL_VERSION"], !envVersion.isEmpty {
      return envVersion
    }
    return RemindctlVersion.current
  }
}
