//
// DashboardSectionRefreshNotifier.swift
//
//

import Foundation

extension Notification.Name {
  static let dashboardSectionsShouldReload = Notification.Name("DashboardSectionsShouldReload")
}

nonisolated enum DashboardSectionRefreshNotifier {
  static let sectionsUserInfoKey = "sections"
  static let sourceUserInfoKey = "source"
  static let reasonUserInfoKey = "reason"
  static let commandUserInfoKey = "command"

  static let bookContentSections: Set<DashboardSection> = [
    .onDeck,
    .recentlyReleasedBooks,
    .recentlyAddedBooks,
  ]

  static let seriesContentSections: Set<DashboardSection> = [
    .recentlyAddedSeries,
    .recentlyUpdatedSeries,
  ]

  static let readingProgressSections: Set<DashboardSection> = [
    .keepReading,
    .onDeck,
    .recentlyReadBooks,
  ]

  static func postBookContentChanged(source: DashboardRefreshSource, reason: String) async {
    await post(sections: bookContentSections, source: source, reason: reason)
  }

  static func postSeriesContentChanged(source: DashboardRefreshSource, reason: String) async {
    await post(sections: seriesContentSections, source: source, reason: reason)
  }

  static func postReadingProgressChanged(source: DashboardRefreshSource, reason: String) async {
    await post(sections: readingProgressSections, source: source, reason: reason)
  }

  static func postReadStatusChanged(source: DashboardRefreshSource, reason: String) async {
    await post(
      sections: readingProgressSections.union(seriesContentSections),
      source: source,
      reason: reason
    )
  }

  static func postCollectionContentChanged(source: DashboardRefreshSource, reason: String) async {
    await post(sections: [.pinnedCollections], source: source, reason: reason)
  }

  static func postReadListContentChanged(source: DashboardRefreshSource, reason: String) async {
    await post(sections: [.pinnedReadLists], source: source, reason: reason)
  }

  static func post(
    sections: Set<DashboardSection>,
    source: DashboardRefreshSource,
    reason: String
  ) async {
    guard !sections.isEmpty else { return }

    await DashboardRefreshCoordinator.shared.requestRefresh(
      sections: sections,
      source: source,
      reason: reason
    )
  }

  static func postAll(source: DashboardRefreshSource, reason: String) async {
    await DashboardRefreshCoordinator.shared.requestRefresh(
      sections: nil,
      source: source,
      reason: reason
    )
  }

  @MainActor
  static func postReload(command: DashboardSectionReloadCommand) {
    var userInfo: [String: Any] = [
      commandUserInfoKey: command,
      sourceUserInfoKey: command.source,
      reasonUserInfoKey: command.reason,
    ]
    if let sections = command.sections {
      userInfo[sectionsUserInfoKey] = sections
    }

    NotificationCenter.default.post(
      name: .dashboardSectionsShouldReload,
      object: nil,
      userInfo: userInfo
    )
  }

  static func reloadCommand(from notification: Notification) -> DashboardSectionReloadCommand? {
    if let command = notification.userInfo?[commandUserInfoKey] as? DashboardSectionReloadCommand {
      return command
    }

    let source =
      notification.userInfo?[sourceUserInfoKey] as? DashboardRefreshSource
      ?? .auto
    let reason =
      notification.userInfo?[reasonUserInfoKey] as? String
      ?? "Dashboard section reload"

    if let sections = notification.userInfo?[sectionsUserInfoKey] as? Set<DashboardSection> {
      return DashboardSectionReloadCommand(
        id: UUID(),
        source: source,
        sections: sections,
        reason: reason
      )
    }

    return DashboardSectionReloadCommand(
      id: UUID(),
      source: source,
      sections: nil,
      reason: reason
    )
  }
}
