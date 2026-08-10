import CoreLocation
import EventKit
import Foundation

final class EventKitFetchContext: @unchecked Sendable {
  let eventStore: EKEventStore
  let calendars: [EKCalendar]

  init(eventStore: EKEventStore, calendars: [EKCalendar]) {
    self.eventStore = eventStore
    self.calendars = calendars
  }
}

final class EventKitFetchCancellation: @unchecked Sendable {
  private let eventStore: EKEventStore
  private let identifier: Any

  init(eventStore: EKEventStore, identifier: Any) {
    self.eventStore = eventStore
    self.identifier = identifier
  }

  func cancel() {
    eventStore.cancelFetchRequest(identifier)
  }
}

final class GeocodeCancellation: @unchecked Sendable {
  let geocoder = CLGeocoder()

  private let lock = NSLock()
  private var task: Task<Void, Never>?
  private var isCancelled = false

  func install(_ task: Task<Void, Never>) {
    let shouldCancel = lock.withLock {
      guard !isCancelled else { return true }
      self.task = task
      return false
    }
    if shouldCancel {
      task.cancel()
    }
  }

  func cancel() {
    let task = lock.withLock {
      isCancelled = true
      let pending = self.task
      self.task = nil
      return pending
    }
    task?.cancel()
    geocoder.cancelGeocode()
  }
}
