import Commander
import Foundation
import RemindCore

enum CompletionCommand {
  static var spec: CommandSpec {
    CommandSpec(
      name: "completion",
      abstract: "Generate shell completion",
      discussion: "Prints a generated completion script.",
      signature: CommandSignatures.withRuntimeFlags(
        CommandSignature(
          arguments: [
            .make(label: "shell", help: "zsh|bash", isOptional: true)
          ]
        )
      ),
      usageExamples: [
        "remindctl completion zsh",
        "remindctl completion bash",
      ]
    ) { values, _ in
      let shell = values.argument(0) ?? "zsh"
      switch shell {
      case "zsh":
        Swift.print(zsh())
      case "bash":
        Swift.print(bash())
      default:
        throw RemindCoreError.operationFailed("Unsupported shell: \(shell) (use zsh|bash)")
      }
    }
  }

  private static var commands: [String] {
    CommandRouter.commandSpecs.map(\.name)
  }

  private static func zsh() -> String {
    """
    #compdef remindctl
    _remindctl() {
      local -a commands
      commands=(\(commands.map { "'\($0):remindctl \($0)'" }.joined(separator: " ")))
      if (( CURRENT == 2 )); then
        _describe 'command' commands
      else
        _arguments '*:argument:_files'
      fi
    }
    _remindctl "$@"
    """
  }

  private static func bash() -> String {
    """
    _remindctl_completion() {
      local cur="${COMP_WORDS[COMP_CWORD]}"
      if [ "$COMP_CWORD" -eq 1 ]; then
        COMPREPLY=( $(compgen -W "\(commands.joined(separator: " "))" -- "$cur") )
      fi
    }
    complete -F _remindctl_completion remindctl
    """
  }
}
