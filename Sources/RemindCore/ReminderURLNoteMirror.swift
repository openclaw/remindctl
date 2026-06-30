import Foundation

enum ReminderURLNoteMirror {
  private static let prefix = "URL: "

  static func apply(notes: String?, showing url: URL?, replacing previousURL: URL? = nil) -> String? {
    let candidateLines = [previousURL, url].compactMap { candidate in
      candidate.map { mirrorLine(for: $0) }
    }
    var lines = (notes ?? "").components(separatedBy: .newlines)
    if !candidateLines.isEmpty {
      lines.removeAll { line in
        candidateLines.contains(line.trimmingCharacters(in: .whitespaces))
      }
    }

    let base = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    guard let url else {
      return base.isEmpty ? nil : base
    }

    let line = mirrorLine(for: url)
    if base.isEmpty {
      return line
    }
    return "\(base)\n\n\(line)"
  }

  private static func mirrorLine(for url: URL) -> String {
    "\(prefix)\(url.absoluteString)"
  }
}
