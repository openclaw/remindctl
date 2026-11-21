import CoreLocation
import EventKit

extension RemindersStore {
  static func locationAlarm(
    from trigger: LocationTrigger,
    geocode: (String) async throws -> CLLocation = geocodeLocation
  ) async throws -> EKAlarm {
    let structuredLocation = EKStructuredLocation(title: trigger.address)
    let location: CLLocation
    if let latitude = trigger.latitude, let longitude = trigger.longitude {
      location = CLLocation(latitude: latitude, longitude: longitude)
    } else {
      location = try await geocode(trigger.address)
    }

    structuredLocation.geoLocation = location
    structuredLocation.radius = trigger.radius

    let alarm = EKAlarm()
    alarm.structuredLocation = structuredLocation
    alarm.proximity = trigger.proximity == .arriving ? .enter : .leave
    return alarm
  }

  private static func geocodeLocation(_ address: String) async throws -> CLLocation {
    let request = GeocodeCancellation()
    let placemarks: [CLPlacemark] = try await AsyncTimeout.withTimeout(
      after: Self.externalOperationTimeout,
      timeoutError: .operationFailed("Timed out geocoding location after 30 seconds")
    ) { completion in
      let task = Task {
        do {
          let placemarks = try await request.geocoder.geocodeAddressString(address)
          completion.resume(returning: placemarks)
        } catch {
          completion.resume(throwing: error)
        }
      }
      request.install(task)
      return { request.cancel() }
    }
    guard let geocodedLocation = placemarks.first?.location else {
      throw RemindCoreError.operationFailed("Could not geocode location: \(address)")
    }
    return geocodedLocation
  }

  static func locationTrigger(from reminder: EKReminder) -> LocationTrigger? {
    guard let alarm = reminder.alarms?.first(where: { $0.structuredLocation != nil }),
      let structuredLocation = alarm.structuredLocation,
      let proximity = LocationProximity(eventKitProximity: alarm.proximity)
    else { return nil }

    let coordinate = structuredLocation.geoLocation?.coordinate
    return LocationTrigger(
      address: structuredLocation.title ?? "",
      latitude: coordinate?.latitude,
      longitude: coordinate?.longitude,
      radius: structuredLocation.radius,
      proximity: proximity
    )
  }
}

extension LocationProximity {
  fileprivate init?(eventKitProximity: EKAlarmProximity) {
    switch eventKitProximity {
    case .enter:
      self = .arriving
    case .leave:
      self = .leaving
    default:
      return nil
    }
  }
}
