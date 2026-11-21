import CoreLocation
import Testing

@testable import RemindCore

struct LocationAlarmTests {
  enum UnexpectedGeocode: Error { case called }

  @Test("Coordinate alarms bypass geocoding and preserve their label and geometry", arguments: [true, false])
  func coordinateAlarm(leaving: Bool) async throws {
    let trigger = LocationTrigger(
      address: "Synthetic label",
      latitude: -12.5,
      longitude: 34.25,
      radius: 200,
      proximity: leaving ? .leaving : .arriving)
    let alarm = try await RemindersStore.locationAlarm(from: trigger) { _ in
      throw UnexpectedGeocode.called
    }
    let location = try #require(alarm.structuredLocation)
    #expect(location.title == "Synthetic label")
    #expect(location.geoLocation?.coordinate.latitude == -12.5)
    #expect(location.geoLocation?.coordinate.longitude == 34.25)
    #expect(location.radius == 200)
    #expect(alarm.proximity == (leaving ? .leave : .enter))
  }

  @Test("Address-only alarms still use the geocoder")
  func addressAlarm() async throws {
    let alarm = try await RemindersStore.locationAlarm(from: LocationTrigger(address: "Synthetic address")) { address in
      #expect(address == "Synthetic address")
      return CLLocation(latitude: 12.5, longitude: -34.25)
    }
    #expect(alarm.structuredLocation?.geoLocation?.coordinate.latitude == 12.5)
    #expect(alarm.structuredLocation?.geoLocation?.coordinate.longitude == -34.25)
  }
}
