import CoreLocation
import EventKit
import Foundation

public actor RemindersStore {
  private let eventStore = EKEventStore()
  private let calendar: Calendar

  public init(calendar: Calendar = .current) {
    self.calendar = calendar
  }

  public func requestAccess() async throws {
    let status = Self.authorizationStatus()
    switch status {
    case .notDetermined:
      let updated = try await requestAuthorization()
      if updated != .fullAccess {
        throw RemindCoreError.accessDenied
      }
    case .denied, .restricted:
      throw RemindCoreError.accessDenied
    case .writeOnly:
      throw RemindCoreError.writeOnlyAccess
    case .fullAccess:
      break
    }
  }

  public static func authorizationStatus() -> RemindersAuthorizationStatus {
    RemindersAuthorizationStatus(eventKitStatus: EKEventStore.authorizationStatus(for: .reminder))
  }

  public func requestAuthorization() async throws -> RemindersAuthorizationStatus {
    let status = Self.authorizationStatus()
    switch status {
    case .notDetermined:
      let granted = try await requestFullAccess()
      return granted ? .fullAccess : .denied
    default:
      return status
    }
  }

  public func lists() async -> [ReminderList] {
    eventStore.calendars(for: .reminder).map { calendar in
      ReminderList(id: calendar.calendarIdentifier, title: calendar.title)
    }
  }

  public func resolveList(_ target: ReminderListTarget) async throws -> ReminderList {
    let lists = await lists()
    switch target {
    case .name(let name):
      return try ListResolver.resolve(name, in: lists)
    case .id(let id):
      return try ListResolver.resolveID(id, in: lists)
    }
  }

  public func defaultListName() -> String? { defaultList()?.title }

  public func defaultList() -> ReminderList? {
    guard let calendar = eventStore.defaultCalendarForNewReminders() else {
      return nil
    }
    return ReminderList(id: calendar.calendarIdentifier, title: calendar.title)
  }

  public func reminders(in listName: String? = nil) async throws -> [ReminderItem] {
    try await reminders(matching: listName.map(ReminderListTarget.name))
  }

  public func reminders(matching target: ReminderListTarget?) async throws -> [ReminderItem] {
    await fetchReminders(in: try calendars(matching: target))
  }

  public func createList(name: String) async throws -> ReminderList {
    let list = EKCalendar(for: .reminder, eventStore: eventStore)
    list.title = name
    guard let source = eventStore.defaultCalendarForNewReminders()?.source else {
      throw RemindCoreError.operationFailed("Unable to determine default reminder source")
    }
    list.source = source
    try eventStore.saveCalendar(list, commit: true)
    return ReminderList(id: list.calendarIdentifier, title: list.title)
  }

  public func renameList(oldName: String, newName: String) async throws {
    try await renameList(target: .name(oldName), newName: newName)
  }

  public func renameList(target: ReminderListTarget, newName: String) async throws {
    let calendar = try calendar(matching: target)
    guard calendar.allowsContentModifications else {
      throw RemindCoreError.operationFailed("Cannot modify system list")
    }
    calendar.title = newName
    try eventStore.saveCalendar(calendar, commit: true)
  }

  public func deleteList(name: String) async throws {
    try await deleteList(target: .name(name))
  }

  public func deleteList(target: ReminderListTarget) async throws {
    let calendar = try calendar(matching: target)
    guard calendar.allowsContentModifications else {
      throw RemindCoreError.operationFailed("Cannot delete system list")
    }
    try eventStore.removeCalendar(calendar, commit: true)
  }

  public func createReminder(_ draft: ReminderDraft, target: ReminderListTarget) async throws -> ReminderItem {
    let calendar = try calendar(matching: target)
    let reminder = EKReminder(eventStore: eventStore)
    reminder.title = draft.title
    reminder.url = draft.url
    // Reminders.app does not surface EventKit's URL field, so also keep one managed notes link.
    reminder.notes = ReminderURLNoteMirror.apply(notes: draft.notes, showing: draft.url)
    reminder.calendar = calendar
    reminder.priority = draft.priority.eventKitValue
    if let dueDate = draft.dueDate {
      reminder.dueDateComponents = calendarComponents(from: dueDate)
    }
    if let alarmDate = draft.alarmDate {
      reminder.addAlarm(EKAlarm(absoluteDate: alarmDate.date))
    } else if let dueDate = draft.dueDate, !dueDate.isDateOnly {
      reminder.addAlarm(EKAlarm(absoluteDate: dueDate.date))
    }
    if let recurrenceRule = draft.recurrenceRule {
      replaceRecurrence(on: reminder, with: recurrenceRule)
    }
    if let locationTrigger = draft.locationTrigger {
      reminder.addAlarm(try await locationAlarm(from: locationTrigger))
    }
    try eventStore.save(reminder, commit: true)
    return item(from: reminder)
  }

  public func updateReminder(id: String, update: ReminderUpdate) async throws -> ReminderItem {
    let reminder = try reminder(withID: id)

    if let title = update.title {
      reminder.title = title
    }
    if update.notes != nil || update.url != nil {
      let merged = ReminderURLNoteMirror.applyingUpdates(
        currentNotes: reminder.notes,
        currentURL: reminder.url,
        notesUpdate: update.notes,
        urlUpdate: update.url
      )
      (reminder.notes, reminder.url) = (merged.notes, merged.url)
    }
    if let dueDateUpdate = update.dueDate {
      if let dueDate = dueDateUpdate {
        reminder.dueDateComponents = nil
        reminder.dueDateComponents = calendarComponents(from: dueDate)
      } else {
        reminder.dueDateComponents = nil
      }
    }
    if let alarmDateUpdate = update.alarmDate {
      ReminderAlarmMutation.replaceDateAlarms(on: reminder, with: alarmDateUpdate?.date)
    }
    if let recurrenceUpdate = update.recurrenceRule {
      replaceRecurrence(on: reminder, with: recurrenceUpdate)
    }
    if let priority = update.priority {
      reminder.priority = priority.eventKitValue
    }
    if let listTarget = update.listTarget {
      reminder.calendar = try calendar(matching: listTarget)
    } else if let listName = update.listName {
      reminder.calendar = try calendar(matching: .name(listName))
    }
    if let isCompleted = update.isCompleted {
      reminder.isCompleted = isCompleted
    }

    try eventStore.save(reminder, commit: true)

    return item(from: reminder)
  }

  public func completeReminders(ids: [String]) async throws -> [ReminderItem] {
    var updated: [ReminderItem] = []
    for id in ids {
      let reminder = try reminder(withID: id)
      reminder.isCompleted = true
      try eventStore.save(reminder, commit: true)
      updated.append(item(from: reminder))
    }
    return updated
  }

  public func deleteReminders(ids: [String]) async throws -> Int {
    var deleted = 0
    for id in ids {
      let reminder = try reminder(withID: id)
      try eventStore.remove(reminder, commit: true)
      deleted += 1
    }
    return deleted
  }
}

extension RemindersStore {
  private func requestFullAccess() async throws -> Bool {
    try await withCheckedThrowingContinuation { continuation in
      eventStore.requestFullAccessToReminders { granted, error in
        if let error {
          continuation.resume(throwing: error)
          return
        }
        continuation.resume(returning: granted)
      }
    }
  }

  private func fetchReminders(in calendars: [EKCalendar]) async -> [ReminderItem] {
    struct ReminderData: Sendable {
      let id: String
      let title: String
      let notes: String?
      let url: URL?
      let isCompleted: Bool
      let completionDate: Date?
      let creationDate: Date?
      let lastModifiedDate: Date?
      let priority: Int
      let dueDateComponents: DateComponents?
      let dueDateIsAllDay: Bool
      let alarmDate: Date?
      let recurrenceRule: RecurrenceRule?
      let locationTrigger: LocationTrigger?
      let listID: String
      let listName: String
    }

    let reminderData = await withCheckedContinuation { (continuation: CheckedContinuation<[ReminderData], Never>) in
      let predicate = eventStore.predicateForReminders(in: calendars)
      eventStore.fetchReminders(matching: predicate) { reminders in
        let data = (reminders ?? []).map { reminder in
          let components = reminder.dueDateComponents
          return ReminderData(
            id: reminder.calendarItemIdentifier,
            title: reminder.title ?? "",
            notes: reminder.notes,
            url: reminder.url,
            isCompleted: reminder.isCompleted,
            completionDate: reminder.completionDate,
            creationDate: reminder.creationDate,
            lastModifiedDate: reminder.lastModifiedDate,
            priority: Int(reminder.priority),
            dueDateComponents: components,
            dueDateIsAllDay: isAllDay(components),
            alarmDate: Self.alarmDate(from: reminder),
            recurrenceRule: Self.recurrenceRule(from: reminder),
            locationTrigger: Self.locationTrigger(from: reminder),
            listID: reminder.calendar.calendarIdentifier,
            listName: reminder.calendar.title
          )
        }
        continuation.resume(returning: data)
      }
    }

    return reminderData.map { data in
      ReminderItem(
        id: data.id,
        title: data.title,
        notes: data.notes,
        url: data.url,
        isCompleted: data.isCompleted,
        completionDate: data.completionDate,
        creationDate: data.creationDate,
        lastModifiedDate: data.lastModifiedDate,
        priority: ReminderPriority(eventKitValue: data.priority),
        dueDate: date(from: data.dueDateComponents),
        dueDateIsAllDay: data.dueDateIsAllDay,
        alarmDate: data.alarmDate,
        recurrenceRule: data.recurrenceRule,
        locationTrigger: data.locationTrigger,
        listID: data.listID,
        listName: data.listName
      )
    }
  }

  private func reminder(withID id: String) throws -> EKReminder {
    guard let item = eventStore.calendarItem(withIdentifier: id) as? EKReminder else {
      throw RemindCoreError.reminderNotFound(id)
    }
    return item
  }

  private func calendar(named name: String) throws -> EKCalendar {
    try calendar(matching: .name(name))
  }

  private func calendar(matching target: ReminderListTarget) throws -> EKCalendar {
    let resolved = try resolvedList(matching: target)
    let calendars = eventStore.calendars(for: .reminder)
    guard let calendar = calendars.first(where: { $0.calendarIdentifier == resolved.id }) else {
      throw RemindCoreError.listNotFound(resolved.id)
    }
    return calendar
  }

  private func calendars(matching target: ReminderListTarget?) throws -> [EKCalendar] {
    let calendars = eventStore.calendars(for: .reminder)
    guard let target else {
      return calendars
    }

    let lists = calendars.map { ReminderList(id: $0.calendarIdentifier, title: $0.title) }
    switch target {
    case .name(let name):
      let resolved = try ListResolver.resolveForRead(name, in: lists)
      let ids = Set(resolved.map(\.id))
      return calendars.filter { ids.contains($0.calendarIdentifier) }
    case .id:
      let resolved = try resolvedList(matching: target, in: lists)
      return calendars.filter { $0.calendarIdentifier == resolved.id }
    }
  }

  private func resolvedList(matching target: ReminderListTarget) throws -> ReminderList {
    let lists = eventStore.calendars(for: .reminder).map { ReminderList(id: $0.calendarIdentifier, title: $0.title) }
    return try resolvedList(matching: target, in: lists)
  }

  private func resolvedList(matching target: ReminderListTarget, in lists: [ReminderList]) throws -> ReminderList {
    switch target {
    case .name(let name):
      return try ListResolver.resolve(name, in: lists)
    case .id(let id):
      return try ListResolver.resolveID(id, in: lists)
    }
  }

  private func calendarComponents(from parsed: ParsedUserDate) -> DateComponents {
    let components: Set<Calendar.Component> =
      parsed.isDateOnly
      ? [.year, .month, .day]
      : [.year, .month, .day, .hour, .minute, .second]
    var result = calendar.dateComponents(components, from: parsed.date)
    result.calendar = calendar
    result.timeZone = calendar.timeZone
    return result
  }

  private func date(from components: DateComponents?) -> Date? {
    guard let components else { return nil }
    return calendar.date(from: components)
  }

  private func item(from reminder: EKReminder) -> ReminderItem {
    let components = reminder.dueDateComponents
    return ReminderItem(
      id: reminder.calendarItemIdentifier,
      title: reminder.title ?? "",
      notes: reminder.notes,
      url: reminder.url,
      isCompleted: reminder.isCompleted,
      completionDate: reminder.completionDate,
      creationDate: reminder.creationDate,
      lastModifiedDate: reminder.lastModifiedDate,
      priority: ReminderPriority(eventKitValue: Int(reminder.priority)),
      dueDate: date(from: components),
      dueDateIsAllDay: isAllDay(components),
      alarmDate: Self.alarmDate(from: reminder),
      recurrenceRule: Self.recurrenceRule(from: reminder),
      locationTrigger: Self.locationTrigger(from: reminder),
      listID: reminder.calendar.calendarIdentifier,
      listName: reminder.calendar.title
    )
  }

  private static func alarmDate(from reminder: EKReminder) -> Date? {
    reminder.alarms?
      .compactMap(\.absoluteDate)
      .min()
  }

  private func replaceRecurrence(on reminder: EKReminder, with rule: RecurrenceRule?) {
    for existing in reminder.recurrenceRules ?? [] {
      reminder.removeRecurrenceRule(existing)
    }
    guard let rule else { return }
    reminder.addRecurrenceRule(
      EKRecurrenceRule(recurrenceWith: rule.eventKitFrequency, interval: rule.interval, end: nil))
  }

  private static func recurrenceRule(from reminder: EKReminder) -> RecurrenceRule? {
    guard let rule = reminder.recurrenceRules?.first else { return nil }
    guard let frequency = RecurrenceFrequency(eventKitFrequency: rule.frequency) else { return nil }
    return RecurrenceRule(frequency: frequency, interval: rule.interval)
  }

  private func locationAlarm(from trigger: LocationTrigger) async throws -> EKAlarm {
    let structuredLocation = EKStructuredLocation(title: trigger.address)
    let location: CLLocation
    if let latitude = trigger.latitude, let longitude = trigger.longitude {
      location = CLLocation(latitude: latitude, longitude: longitude)
    } else {
      let placemarks = try await CLGeocoder().geocodeAddressString(trigger.address)
      guard let geocodedLocation = placemarks.first?.location else {
        throw RemindCoreError.operationFailed("Could not geocode location: \(trigger.address)")
      }
      location = geocodedLocation
    }

    structuredLocation.geoLocation = location
    structuredLocation.radius = trigger.radius

    let alarm = EKAlarm()
    alarm.structuredLocation = structuredLocation
    alarm.proximity = trigger.proximity == .arriving ? .enter : .leave
    return alarm
  }

  private static func locationTrigger(from reminder: EKReminder) -> LocationTrigger? {
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

extension RecurrenceFrequency {
  fileprivate init?(eventKitFrequency: EKRecurrenceFrequency) {
    switch eventKitFrequency {
    case .daily:
      self = .daily
    case .weekly:
      self = .weekly
    case .monthly:
      self = .monthly
    case .yearly:
      self = .yearly
    @unknown default:
      return nil
    }
  }

  fileprivate var eventKitFrequency: EKRecurrenceFrequency {
    switch self {
    case .daily:
      return .daily
    case .weekly:
      return .weekly
    case .monthly:
      return .monthly
    case .yearly:
      return .yearly
    }
  }
}

extension RecurrenceRule {
  fileprivate var eventKitFrequency: EKRecurrenceFrequency {
    frequency.eventKitFrequency
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
