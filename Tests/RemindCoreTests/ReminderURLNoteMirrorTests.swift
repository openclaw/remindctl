import Foundation
import Testing

@testable import RemindCore

struct ReminderURLNoteMirrorTests {
  @Test("URL mirror creates a tool-owned app-visible note line")
  func createsToolOwnedURLLine() {
    let url = URL(string: "https://example.com/product")!

    #expect(ReminderURLNoteMirror.apply(notes: nil, showing: url) == "remindctl URL: https://example.com/product")
    #expect(
      ReminderURLNoteMirror.apply(notes: "Compare prices", showing: url)
        == "Compare prices\n\nremindctl URL: https://example.com/product"
    )
  }

  @Test("URL mirror does not duplicate an existing tool-owned line")
  func avoidsDuplicateToolOwnedURLLine() {
    let url = URL(string: "https://example.com/product")!

    #expect(
      ReminderURLNoteMirror.apply(notes: "Compare prices\n\nremindctl URL: https://example.com/product", showing: url)
        == "Compare prices\n\nremindctl URL: https://example.com/product"
    )
  }

  @Test("URL mirror replaces and clears the previous tool-owned line")
  func replacesAndClearsPreviousToolOwnedURLLine() {
    let oldURL = URL(string: "https://example.com/old")!
    let newURL = URL(string: "https://example.com/new")!

    #expect(
      ReminderURLNoteMirror.apply(
        notes: "Compare prices\n\nremindctl URL: https://example.com/old",
        showing: newURL,
        replacing: oldURL
      )
        == "Compare prices\n\nremindctl URL: https://example.com/new"
    )
    #expect(
      ReminderURLNoteMirror.apply(
        notes: "Compare prices\n\nremindctl URL: https://example.com/old",
        showing: nil,
        replacing: oldURL
      )
        == "Compare prices"
    )
  }

  @Test("URL mirror preserves authored URL note lines")
  func preservesAuthoredURLLines() {
    let oldURL = URL(string: "https://example.com/old")!
    let newURL = URL(string: "https://example.com/new")!

    #expect(
      ReminderURLNoteMirror.apply(
        notes: "URL: https://example.com/old",
        showing: nil,
        replacing: oldURL
      )
        == "URL: https://example.com/old"
    )
    #expect(
      ReminderURLNoteMirror.apply(
        notes: "URL: https://example.com/old",
        showing: newURL,
        replacing: oldURL
      )
        == "URL: https://example.com/old\n\nremindctl URL: https://example.com/new"
    )
  }
}
