import Commander
import Foundation

enum ParsedValuesError: LocalizedError, CustomStringConvertible {
  case missingArgument(String)

  var description: String {
    switch self {
    case .missingArgument(let name):
      return "Missing required argument: \(name)"
    }
  }

  var errorDescription: String? {
    description
  }
}

extension ParsedValues {
  func flag(_ label: String) -> Bool {
    flags.contains(label)
  }

  func option(_ label: String) -> String? {
    options[label]?.last
  }

  func argument(_ index: Int) -> String? {
    guard positional.indices.contains(index) else { return nil }
    return positional[index]
  }
}
