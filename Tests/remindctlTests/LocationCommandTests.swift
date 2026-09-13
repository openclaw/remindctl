import RemindCore
import Testing

@testable import remindctl

struct LocationCommandTests {
  @Test("Location radii must be finite and positive", arguments: ["inf", "+inf", "1e309", "nan", "0", "-1"])
  func invalidRadius(_ value: String) {
    #expect(throws: RemindCoreError.operationFailed("Invalid radius: \"\(value)\"")) {
      try AddCommand.makeLocationTrigger(location: "Synthetic address", radius: value, leaving: false)
    }
  }

  @Test("Valid location options preserve radius and proximity")
  func validRadius() throws {
    let trigger = try #require(
      try AddCommand.makeLocationTrigger(location: "Synthetic address", radius: "200", leaving: true))
    #expect(trigger.radius == 200)
    #expect(trigger.proximity == .leaving)
  }
}
