import Foundation

enum ReminderURLNoteMirror {
  private static let prefix = "remindctl URL (managed): "

  static func applyingUpdates(
    currentNotes: String?,
    currentURL: URL?,
    notesUpdate: String?,
    urlUpdate: URL??
  ) -> (notes: String?, url: URL?) {
    let nextNotes = notesUpdate ?? currentNotes
    let nextURL = urlUpdate ?? currentURL
    return (apply(notes: nextNotes, showing: nextURL, replacing: currentURL), nextURL)
  }

  static func apply(notes: String?, showing url: URL?, replacing previousURL: URL? = nil) -> String? {
    guard url != nil || previousURL != nil else {
      return notes
    }

    let candidateLines = Set(
      [previousURL, url].compactMap { candidate in
        candidate.map { mirrorLine(for: $0) }
      })
    let removal = removeManagedLines(from: notes, matching: candidateLines)
    let base = removal.notes ?? ""
    guard let url else {
      if base.isEmpty, removal.removedManagedLine {
        return nil
      }
      return removal.notes
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

  private static func removeManagedLines(
    from notes: String?,
    matching candidateLines: Set<String>
  ) -> (notes: String?, removedManagedLine: Bool) {
    guard !candidateLines.isEmpty, var text = notes else {
      return (notes, false)
    }

    var removedManagedLine = false
    for candidateLine in candidateLines {
      let removal = removeManagedLine(candidateLine, from: text)
      text = removal.notes
      removedManagedLine = removedManagedLine || removal.removedManagedLine
    }
    return (text, removedManagedLine)
  }

  private static func removeManagedLine(
    _ candidateLine: String,
    from text: String
  ) -> (notes: String, removedManagedLine: Bool) {
    if text == candidateLine {
      return ("", true)
    }

    for separator in ["\r\n\r\n", "\n\n", "\r\r"] {
      let generatedBlock = "\(separator)\(candidateLine)"
      if text.hasSuffix(generatedBlock) {
        return (String(text.dropLast(generatedBlock.count)), true)
      }
    }

    var result = ""
    var removedManagedLine = false
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
      } else {
        removedManagedLine = true
      }
      lineStart = nextLineStart
    }

    return (result, removedManagedLine)
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
