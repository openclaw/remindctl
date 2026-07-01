import Foundation
import Testing

@testable import RemindCore

struct ReminderURLNoteMirrorTests {
  @Test("Notes-only updates keep the current URL visible")
  func notesOnlyUpdatesKeepCurrentURLVisible() {
    let url = URL(string: "https://example.com/product")!

    let updated = ReminderURLNoteMirror.applyingUpdates(
      currentNotes: "Old notes\n\nremindctl URL (managed): https://example.com/product",
      currentURL: url,
      notesUpdate: "New notes",
      urlUpdate: nil
    )

    #expect(updated.url == url)
    #expect(updated.notes == "New notes\n\nremindctl URL (managed): https://example.com/product")
  }

  @Test("URL updates merge set and clear behavior with current notes")
  func urlUpdatesMergeWithCurrentNotes() {
    let oldURL = URL(string: "https://example.com/old")!
    let newURL = URL(string: "https://example.com/new")!

    let replaced = ReminderURLNoteMirror.applyingUpdates(
      currentNotes: "Notes\n\nremindctl URL (managed): https://example.com/old",
      currentURL: oldURL,
      notesUpdate: nil,
      urlUpdate: .some(newURL)
    )
    #expect(replaced.url == newURL)
    #expect(replaced.notes == "Notes\n\nremindctl URL (managed): https://example.com/new")

    let cleared = ReminderURLNoteMirror.applyingUpdates(
      currentNotes: replaced.notes,
      currentURL: replaced.url,
      notesUpdate: nil,
      urlUpdate: .some(nil)
    )
    #expect(cleared.url == nil)
    #expect(cleared.notes == "Notes")
  }

  @Test("URL mirror preserves notes-only text when no mirror is involved")
  func preservesNotesOnlyTextWhenNoMirrorIsInvolved() {
    let emptyNote = ReminderURLNoteMirror.apply(notes: "", showing: nil)

    #expect(ReminderURLNoteMirror.apply(notes: "  Keep spacing\n\n", showing: nil) == "  Keep spacing\n\n")
    #expect(emptyNote != nil)
    #expect(emptyNote?.isEmpty == true)
    #expect(ReminderURLNoteMirror.apply(notes: nil, showing: nil) == nil)
  }

  @Test("URL mirror creates a tool-owned app-visible note line")
  func createsToolOwnedURLLine() {
    let url = URL(string: "https://example.com/product")!

    #expect(
      ReminderURLNoteMirror.apply(notes: nil, showing: url) == "remindctl URL (managed): https://example.com/product")
    #expect(
      ReminderURLNoteMirror.apply(notes: "Compare prices", showing: url)
        == "Compare prices\n\nremindctl URL (managed): https://example.com/product"
    )
  }

  @Test("URL mirror does not duplicate an existing tool-owned line")
  func avoidsDuplicateToolOwnedURLLine() {
    let url = URL(string: "https://example.com/product")!

    #expect(
      ReminderURLNoteMirror.apply(
        notes: "Compare prices\n\nremindctl URL (managed): https://example.com/product", showing: url)
        == "Compare prices\n\nremindctl URL (managed): https://example.com/product"
    )
  }

  @Test("URL mirror replaces and clears the previous tool-owned line")
  func replacesAndClearsPreviousToolOwnedURLLine() {
    let oldURL = URL(string: "https://example.com/old")!
    let newURL = URL(string: "https://example.com/new")!

    #expect(
      ReminderURLNoteMirror.apply(
        notes: "Compare prices\n\nremindctl URL (managed): https://example.com/old",
        showing: newURL,
        replacing: oldURL
      )
        == "Compare prices\n\nremindctl URL (managed): https://example.com/new"
    )
    #expect(
      ReminderURLNoteMirror.apply(
        notes: "Compare prices\n\nremindctl URL (managed): https://example.com/old",
        showing: nil,
        replacing: oldURL
      )
        == "Compare prices"
    )
  }

  @Test("URL mirror preserves authored whitespace around replace and clear")
  func preservesAuthoredWhitespaceAroundReplaceAndClear() {
    let oldURL = URL(string: "https://example.com/old")!
    let newURL = URL(string: "https://example.com/new")!
    let authoredNotes = "  Keep spacing\n\n"

    let withOldMirror = ReminderURLNoteMirror.apply(notes: authoredNotes, showing: oldURL)

    #expect(withOldMirror == "  Keep spacing\n\n\n\nremindctl URL (managed): https://example.com/old")
    #expect(
      ReminderURLNoteMirror.apply(notes: withOldMirror, showing: newURL, replacing: oldURL)
        == "  Keep spacing\n\n\n\nremindctl URL (managed): https://example.com/new"
    )
    #expect(ReminderURLNoteMirror.apply(notes: withOldMirror, showing: nil, replacing: oldURL) == authoredNotes)
  }

  @Test("URL mirror preserves authored newline style")
  func preservesAuthoredNewlineStyle() {
    let url = URL(string: "https://example.com/product")!
    let authoredNotes = "Line one\r\nLine two"

    let withMirror = ReminderURLNoteMirror.apply(notes: authoredNotes, showing: url)

    #expect(withMirror == "Line one\r\nLine two\r\n\r\nremindctl URL (managed): https://example.com/product")
    #expect(ReminderURLNoteMirror.apply(notes: withMirror, showing: nil, replacing: url) == authoredNotes)
  }

  @Test("URL mirror preserves authored empty notes when clearing without a managed line")
  func preservesAuthoredEmptyNotesWhenClearingWithoutManagedLine() {
    let oldURL = URL(string: "https://example.com/old")!

    let clearedNotes = ReminderURLNoteMirror.apply(notes: "", showing: nil, replacing: oldURL)

    #expect(clearedNotes != nil)
    #expect(clearedNotes?.isEmpty == true)
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
        == "URL: https://example.com/old\n\nremindctl URL (managed): https://example.com/new"
    )
  }

  @Test("URL mirror preserves authored plain remindctl URL lines")
  func preservesAuthoredPlainRemindctlURLLines() {
    let oldURL = URL(string: "https://example.com/old")!
    let newURL = URL(string: "https://example.com/new")!

    #expect(
      ReminderURLNoteMirror.apply(
        notes: "remindctl URL: https://example.com/old",
        showing: nil,
        replacing: oldURL
      )
        == "remindctl URL: https://example.com/old"
    )
    #expect(
      ReminderURLNoteMirror.apply(
        notes: "remindctl URL: https://example.com/old",
        showing: newURL,
        replacing: oldURL
      )
        == "remindctl URL: https://example.com/old\n\nremindctl URL (managed): https://example.com/new"
    )
  }
}
