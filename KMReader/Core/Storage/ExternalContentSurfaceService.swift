//
// ExternalContentSurfaceService.swift
//
//

import Foundation

@MainActor
enum ExternalContentSurfaceService {
  static func updateAfterSelectingInstance(instanceId: String, protected: Bool) {
    guard !instanceId.isEmpty else {
      clearAll()
      return
    }

    guard !protected else {
      clearAll()
      return
    }

    WidgetDataService.refreshWidgetData()
    #if os(iOS) || os(macOS)
      SpotlightIndexService.removeAllItems()
      SpotlightIndexService.indexAllDownloadedBooks(instanceId: instanceId)
    #endif
  }

  static func refreshWidgetsForCurrentInstance() async {
    guard !AppConfig.current.instanceId.isEmpty else {
      clearAll()
      return
    }

    guard !(await isCurrentInstanceProtected()) else {
      clearAll()
      return
    }

    WidgetDataService.refreshWidgetData()
  }

  static func clearAll() {
    WidgetDataService.clearWidgetData()
    #if os(iOS) || os(macOS)
      SpotlightIndexService.removeAllItems()
    #endif
  }

  private static func isCurrentInstanceProtected() async -> Bool {
    let instanceId = AppConfig.current.instanceId
    guard !instanceId.isEmpty else { return false }

    do {
      let database = try await DatabaseOperator.database()
      return try await database.isServerProtected(instanceId: instanceId)
    } catch {
      AppLogger(.app).error(
        "Failed to check protected server state for external content: \(error.localizedDescription)"
      )
      return true
    }
  }
}
