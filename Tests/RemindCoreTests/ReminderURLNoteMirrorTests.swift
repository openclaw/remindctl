import Foundation
import Testing

@testable import RemindCore

struct ReminderURLNoteMirrorTests {
  @Test("URL mirror creates an app-visible note line")
  func createsURLLine() {
    let url = URL(string: "https://example.com/product")!

    #expect(ReminderURLNoteMirror.apply(notes: nil, showing: url) == "URL: https://example.com/product")
    #expect(
      ReminderURLNoteMirror.apply(notes: "Compare prices", showing: url)
        == "Compare prices\n\nURL: https://example.com/product"
    )
  }

  @Test("URL mirror does not duplicate an existing matching line")
  func avoidsDuplicateURLLine() {
    let url = URL(string: "https://example.com/product")!

    #expect(
      ReminderURLNoteMirror.apply(notes: "Compare prices\n\nURL: https://example.com/product", showing: url)
        == "Compare prices\n\nURL: https://example.com/product"
    )
  }

  @Test("URL mirror replaces and clears the previous mirrored line")
  func replacesAndClearsPreviousURLLine() {
    let oldURL = URL(string: "https://example.com/old")!
    let newURL = URL(string: "https://example.com/new")!

    #expect(
      ReminderURLNoteMirror.apply(
        notes: "Compare prices\n\nURL: https://example.com/old",
        showing: newURL,
        replacing: oldURL
      )
        == "Compare prices\n\nURL: https://example.com/new"
    )
    #expect(
      ReminderURLNoteMirror.apply(
        notes: "Compare prices\n\nURL: https://example.com/old",
        showing: nil,
        replacing: oldURL
      )
        == "Compare prices"
    )
  }
}
