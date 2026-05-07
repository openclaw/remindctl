import Foundation

enum IndexCache {
  private struct Payload: Codable {
    let savedAt: Date
    let reminderIDs: [String]
  }

  static var path: URL {
    let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
      ?? URL(fileURLWithPath: NSTemporaryDirectory())
    return cachesDir.appending(path: "remindctl/index.json")
  }

  static func save(_ ids: [String]) throws {
    let url = path
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(Payload(savedAt: Date(), reminderIDs: ids))
    try data.write(to: url, options: .atomic)
  }

  static func load() -> [String]? {
    guard let data = try? Data(contentsOf: path) else { return nil }
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return (try? decoder.decode(Payload.self, from: data))?.reminderIDs
  }
}
