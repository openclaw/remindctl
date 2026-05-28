import EventKit
import Testing

@testable import RemindCore

@MainActor
struct AuthorizationStatusTests {
  @Test("Authorization status mapping")
  func mapping() {
    #expect(RemindersAuthorizationStatus(eventKitStatus: .fullAccess) == .fullAccess)
    #expect(RemindersAuthorizationStatus(eventKitStatus: .writeOnly) == .writeOnly)
    #expect(RemindersAuthorizationStatus(eventKitStatus: .denied) == .denied)
    #expect(RemindersAuthorizationStatus(eventKitStatus: .restricted) == .restricted)
    #expect(RemindersAuthorizationStatus(eventKitStatus: .notDetermined) == .notDetermined)
  }

  @Test("Authorization display names")
  func displayNames() {
    #expect(!RemindersAuthorizationStatus.notDetermined.isAuthorized)
    #expect(!RemindersAuthorizationStatus.restricted.isAuthorized)
    #expect(!RemindersAuthorizationStatus.denied.isAuthorized)
    #expect(!RemindersAuthorizationStatus.writeOnly.isAuthorized)
    #expect(RemindersAuthorizationStatus.fullAccess.isAuthorized)
    #expect(RemindersAuthorizationStatus.notDetermined.displayName == "Not determined")
    #expect(RemindersAuthorizationStatus.restricted.displayName == "Restricted")
    #expect(RemindersAuthorizationStatus.fullAccess.displayName == "Full access")
    #expect(RemindersAuthorizationStatus.writeOnly.displayName == "Write-only")
    #expect(RemindersAuthorizationStatus.denied.displayName == "Denied")
  }
}
