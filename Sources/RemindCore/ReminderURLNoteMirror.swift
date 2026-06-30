import Foundation

enum ReminderURLNoteMirror {
  private static let prefix = "remindctl URL: "

  static func apply(notes: String?, showing url: URL?, replacing previousURL: URL? = nil) -> String? {
    guard url != nil || previousURL != nil else {
      return notes
    }

    let candidateLines = Set(
      [previousURL, url].compactMap { candidate in
        candidate.map { mirrorLine(for: $0) }
      })
    let base = removeManagedLines(from: notes, matching: candidateLines) ?? ""
    guard let url else {
      return base.isEmpty ? nil : base
    }

    let line = mirrorLine(for: url)
    if base.isEmpty {
      return line
    }
    return "\(base)\(separator(beforeAppendingTo: base))\(line)"
  }

  private static func mirrorLine(for url: URL) -> String {
    "\(prefix)\(url.absoluteString)"
  }

  private static func removeManagedLines(from notes: String?, matching candidateLines: Set<String>) -> String? {
    guard !candidateLines.isEmpty, var text = notes else {
      return notes
    }

    for candidateLine in candidateLines {
      text = removeManagedLine(candidateLine, from: text)
    }
    return text
  }

  private static func removeManagedLine(_ candidateLine: String, from text: String) -> String {
    if text == candidateLine {
      return ""
    }

    for separator in ["\r\n\r\n", "\n\n", "\r\r"] {
      let generatedBlock = "\(separator)\(candidateLine)"
      if text.hasSuffix(generatedBlock) {
        return String(text.dropLast(generatedBlock.count))
      }
    }

    var result = ""
    var lineStart = text.startIndex
    while lineStart < text.endIndex {
      var lineEnd = lineStart
      while lineEnd < text.endIndex, text[lineEnd] != "\n", text[lineEnd] != "\r" {
        lineEnd = text.index(after: lineEnd)
      }

      var nextLineStart = lineEnd
      if nextLineStart < text.endIndex {
        if text[nextLineStart] == "\r" {
          nextLineStart = text.index(after: nextLineStart)
          if nextLineStart < text.endIndex, text[nextLineStart] == "\n" {
            nextLineStart = text.index(after: nextLineStart)
          }
        } else {
          nextLineStart = text.index(after: nextLineStart)
        }
      }

      let line = String(text[lineStart..<lineEnd])
      if line.trimmingCharacters(in: .whitespaces) != candidateLine {
        result += text[lineStart..<nextLineStart]
      }
      lineStart = nextLineStart
    }

    return result
  }

  private static func separator(beforeAppendingTo notes: String) -> String {
    if notes.contains("\r\n") {
      return "\r\n\r\n"
    }
    if notes.contains("\r") {
      return "\r\r"
    }
    return "\n\n"
  }
}
