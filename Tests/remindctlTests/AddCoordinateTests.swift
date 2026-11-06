import RemindCore
import Testing

@testable import remindctl

struct AddCoordinateTests {
  @Test("The add parser accepts coordinate options", arguments: [true, false])
  func coordinateOptions(labeled: Bool) throws {
    var arguments = [
      "remindctl", "add", "Synthetic coordinate reminder", "--latitude", "-12.5", "--longitude=34.25",
      "--radius", "200", "--leaving",
    ]
    if labeled { arguments += ["--location", "Synthetic label"] }
    let values = try CommandRouter().program.resolve(arguments: arguments).parsedValues
    let trigger = try #require(
      try AddCommand.makeLocationTrigger(
        location: values.option("location"),
        radius: values.option("radius"),
        leaving: values.flag("leaving"),
        latitude: values.option("latitude"),
        longitude: values.option("longitude")))
    #expect(trigger.latitude == -12.5)
    #expect(trigger.longitude == 34.25)
    #expect(trigger.address == (labeled ? "Synthetic label" : ""))
    #expect(trigger.radius == 200)
    #expect(trigger.proximity == .leaving)
  }

  @Test(
    "Coordinate pairs include zero and their range boundaries",
    arguments: [
      ("0", "0"), ("-90", "-180"), ("90", "180"), ("1e1", "-2e1"),
    ])
  func coordinateBoundaries(pair: (String, String)) throws {
    let trigger = try #require(
      try AddCommand.makeLocationTrigger(
        location: nil, radius: nil, leaving: false, latitude: pair.0, longitude: pair.1))
    #expect(trigger.latitude == Double(pair.0))
    #expect(trigger.longitude == Double(pair.1))
    #expect(trigger.radius == 100)
    #expect(trigger.proximity == .arriving)
  }

  @Test("Coordinates must be supplied together", arguments: [true, false])
  func missingCoordinate(latitudeOnly: Bool) {
    #expect(throws: RemindCoreError.operationFailed("Provide --latitude and --longitude together")) {
      try AddCommand.makeLocationTrigger(
        location: "Synthetic label",
        radius: nil,
        leaving: false,
        latitude: latitudeOnly ? "12.5" : nil,
        longitude: latitudeOnly ? nil : "34.25")
    }
  }

  @Test(
    "Latitude must be finite and in range",
    arguments: [
      "nan", "inf", "+inf", "-inf", "1e309", "90.001", "-90.001", "text", "",
    ])
  func invalidLatitude(_ value: String) {
    #expect(throws: (any Error).self) {
      try AddCommand.makeLocationTrigger(
        location: nil, radius: nil, leaving: false, latitude: value, longitude: "34.25")
    }
  }

  @Test(
    "Longitude must be finite and in range",
    arguments: [
      "nan", "inf", "+inf", "-inf", "1e309", "180.001", "-180.001", "text", "",
    ])
  func invalidLongitude(_ value: String) {
    #expect(throws: (any Error).self) {
      try AddCommand.makeLocationTrigger(
        location: nil, radius: nil, leaving: false, latitude: "12.5", longitude: value)
    }
  }

  @Test("Coordinate triggers still validate radius", arguments: ["nan", "inf", "0", "-1"])
  func invalidRadius(_ value: String) {
    #expect(throws: RemindCoreError.operationFailed("Invalid radius: \"\(value)\"")) {
      try AddCommand.makeLocationTrigger(
        location: nil, radius: value, leaving: false, latitude: "12.5", longitude: "34.25")
    }
  }

  @Test("Address-only and absent locations preserve their behavior")
  func addressOnly() throws {
    let trigger = try #require(
      try AddCommand.makeLocationTrigger(location: "Synthetic address", radius: nil, leaving: false))
    #expect(trigger.address == "Synthetic address")
    #expect(trigger.latitude == nil)
    #expect(trigger.longitude == nil)
    #expect(trigger.radius == 100)
    #expect(trigger.proximity == .arriving)
    #expect(try AddCommand.makeLocationTrigger(location: nil, radius: nil, leaving: false) == nil)
  }
}
