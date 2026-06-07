import Foundation

public enum ReminderPriority: String, Codable, CaseIterable, Sendable {
  case none
  case low
  case medium
  case high

  public init(eventKitValue: Int) {
    switch eventKitValue {
    case 1...4:
      self = .high
    case 5:
      self = .medium
    case 6...9:
      self = .low
    default:
      self = .none
    }
  }

  public var eventKitValue: Int {
    switch self {
    case .none:
      return 0
    case .high:
      return 1
    case .medium:
      return 5
    case .low:
      return 9
    }
  }
}

public enum RecurrenceFrequency: String, Codable, CaseIterable, Sendable {
  case daily
  case weekly
  case monthly
  case yearly
}

public struct RecurrenceRule: Codable, Sendable, Equatable {
  public let frequency: RecurrenceFrequency
  public let interval: Int

  public init(frequency: RecurrenceFrequency, interval: Int = 1) {
    self.frequency = frequency
    self.interval = interval
  }

  public var displayString: String {
    if interval == 1 {
      return frequency.rawValue
    }
    let unit =
      switch frequency {
      case .daily: "days"
      case .weekly: "weeks"
      case .monthly: "months"
      case .yearly: "years"
      }
    return "every \(interval) \(unit)"
  }
}

public struct ReminderList: Identifiable, Codable, Sendable, Equatable {
  public let id: String
  public let title: String

  public init(id: String, title: String) {
    self.id = id
    self.title = title
  }
}

public enum ReminderListTarget: Sendable, Equatable {
  case name(String)
  case id(String)
}

public enum LocationProximity: String, Codable, CaseIterable, Sendable {
  case arriving
  case leaving
}

public struct LocationTrigger: Codable, Sendable, Equatable {
  public let address: String
  public let latitude: Double?
  public let longitude: Double?
  public let radius: Double
  public let proximity: LocationProximity

  public init(
    address: String,
    latitude: Double? = nil,
    longitude: Double? = nil,
    radius: Double = 100,
    proximity: LocationProximity = .arriving
  ) {
    self.address = address
    self.latitude = latitude
    self.longitude = longitude
    self.radius = radius
    self.proximity = proximity
  }
}

public struct ReminderItem: Identifiable, Codable, Sendable, Equatable {
  public let id: String
  public let title: String
  public let notes: String?
  public let url: URL?
  public let isCompleted: Bool
  public let completionDate: Date?
  public let creationDate: Date?
  public let lastModifiedDate: Date?
  public let priority: ReminderPriority
  public let dueDate: Date?
  public let dueDateIsAllDay: Bool
  public let alarmDate: Date?
  public let recurrenceRule: RecurrenceRule?
  public let locationTrigger: LocationTrigger?
  public let listID: String
  public let listName: String

  public init(
    id: String,
    title: String,
    notes: String?,
    url: URL? = nil,
    isCompleted: Bool,
    completionDate: Date?,
    creationDate: Date? = nil,
    lastModifiedDate: Date? = nil,
    priority: ReminderPriority,
    dueDate: Date?,
    dueDateIsAllDay: Bool = false,
    alarmDate: Date? = nil,
    recurrenceRule: RecurrenceRule? = nil,
    locationTrigger: LocationTrigger? = nil,
    listID: String,
    listName: String
  ) {
    self.id = id
    self.title = title
    self.notes = notes
    self.url = url
    self.isCompleted = isCompleted
    self.completionDate = completionDate
    self.creationDate = creationDate
    self.lastModifiedDate = lastModifiedDate
    self.priority = priority
    self.dueDate = dueDate
    self.dueDateIsAllDay = dueDateIsAllDay
    self.alarmDate = alarmDate
    self.recurrenceRule = recurrenceRule
    self.locationTrigger = locationTrigger
    self.listID = listID
    self.listName = listName
  }
}

public struct ReminderDraft: Sendable {
  public let title: String
  public let notes: String?
  public let url: URL?
  public let dueDate: ParsedUserDate?
  public let alarmDate: ParsedUserDate?
  public let recurrenceRule: RecurrenceRule?
  public let locationTrigger: LocationTrigger?
  public let priority: ReminderPriority

  public init(
    title: String,
    notes: String?,
    url: URL? = nil,
    dueDate: ParsedUserDate?,
    alarmDate: ParsedUserDate? = nil,
    recurrenceRule: RecurrenceRule? = nil,
    locationTrigger: LocationTrigger? = nil,
    priority: ReminderPriority
  ) {
    self.title = title
    self.notes = notes
    self.url = url
    self.dueDate = dueDate
    self.alarmDate = alarmDate
    self.recurrenceRule = recurrenceRule
    self.locationTrigger = locationTrigger
    self.priority = priority
  }
}

public struct ReminderUpdate: Sendable {
  public let title: String?
  public let notes: String?
  // Double optional: nil = leave unchanged, .some(nil) = clear, .some(url) = set.
  public let url: URL??
  public let dueDate: ParsedUserDate??
  public let alarmDate: ParsedUserDate??
  public let recurrenceRule: RecurrenceRule??
  public let priority: ReminderPriority?
  public let listName: String?
  public let listTarget: ReminderListTarget?
  public let isCompleted: Bool?

  public init(
    title: String? = nil,
    notes: String? = nil,
    url: URL?? = nil,
    dueDate: ParsedUserDate?? = nil,
    alarmDate: ParsedUserDate?? = nil,
    recurrenceRule: RecurrenceRule?? = nil,
    priority: ReminderPriority? = nil,
    listName: String? = nil,
    listTarget: ReminderListTarget? = nil,
    isCompleted: Bool? = nil
  ) {
    self.title = title
    self.notes = notes
    self.url = url
    self.dueDate = dueDate
    self.alarmDate = alarmDate
    self.recurrenceRule = recurrenceRule
    self.priority = priority
    self.listName = listName
    self.listTarget = listTarget
    self.isCompleted = isCompleted
  }
}
