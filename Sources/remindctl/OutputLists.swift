import Foundation

extension OutputRenderer {
  static func printLists(_ summaries: [ListSummary], format: OutputFormat) {
    switch format {
    case .standard:
      printListsStandard(summaries)
    case .table:
      printListsTable(summaries)
    case .plain:
      printListsPlain(summaries)
    case .json:
      printJSON(summaries)
    case .quiet:
      Swift.print(summaries.count)
    }
  }

  private static func printListsStandard(_ summaries: [ListSummary]) {
    guard !summaries.isEmpty else {
      Swift.print("No reminder lists found")
      return
    }
    for summary in summaries.sorted(by: { $0.title < $1.title }) {
      let overdue = summary.overdueCount > 0 ? " (\(summary.overdueCount) overdue)" : ""
      Swift.print("\(summary.title) — \(summary.reminderCount) reminders\(overdue)")
    }
  }

  private static func printListsPlain(_ summaries: [ListSummary]) {
    for summary in summaries.sorted(by: { $0.title < $1.title }) {
      Swift.print("\(summary.title)\t\(summary.reminderCount)\t\(summary.overdueCount)")
    }
  }

  private static func printListsTable(_ summaries: [ListSummary]) {
    Swift.print(["ID", "Title", "Open", "Overdue"].joined(separator: "\t"))
    for summary in summaries.sorted(by: { $0.title < $1.title }) {
      Swift.print(
        [
          String(summary.id.prefix(8)),
          summary.title,
          "\(summary.reminderCount)",
          "\(summary.overdueCount)",
        ].joined(separator: "\t"))
    }
  }

}
