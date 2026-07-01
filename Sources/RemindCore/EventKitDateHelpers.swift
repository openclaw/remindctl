import Foundation

func isAllDay(_ components: DateComponents?) -> Bool {
  guard let components else { return false }
  return components.hour == nil && components.minute == nil && components.second == nil
}
