import Foundation
import Testing

@testable import remindctl

struct URLCommandTests {
  @Test("URL parsing requires an explicit scheme")
  func parseURLRequiresScheme() throws {
    let url = try CommandHelpers.parseURL("https://example.com/product")
    #expect(url.absoluteString == "https://example.com/product")

    #expect(throws: Error.self) {
      _ = try CommandHelpers.parseURL("example.com/product")
    }
    #expect(throws: Error.self) {
      _ = try CommandHelpers.parseURL("   ")
    }
  }

  @Test("Edit URL update preserves set clear and leave semantics")
  func editURLUpdateSemantics() throws {
    let setUpdate = try EditCommand.parsedURLUpdate(urlValue: "https://example.com/product", clearURL: false)
    #expect(setUpdate != nil)
    #expect(setUpdate!! == URL(string: "https://example.com/product")!)

    let clearUpdate = try EditCommand.parsedURLUpdate(urlValue: nil, clearURL: true)
    #expect(clearUpdate != nil)
    #expect(clearUpdate! == nil)

    let noChange = try EditCommand.parsedURLUpdate(urlValue: nil, clearURL: false)
    #expect(noChange == nil)
  }

  @Test("Edit URL update rejects conflicting set and clear flags")
  func editURLUpdateRejectsConflict() {
    #expect(throws: Error.self) {
      _ = try EditCommand.parsedURLUpdate(urlValue: "https://example.com/product", clearURL: true)
    }
  }
}
