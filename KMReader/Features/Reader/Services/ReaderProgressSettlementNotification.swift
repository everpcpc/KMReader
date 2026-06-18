//
// ReaderProgressSettlementNotification.swift
//
//

import Foundation

extension Notification.Name {
  static let readerProgressDidSettle = Notification.Name("ReaderProgressDidSettle")
}

enum ReaderProgressSettlementNotification {
  static let localProjectionRefreshDelay: UInt64 = 750_000_000
  static let remoteProjectionRefreshDelay: UInt64 = 5_000_000_000

  private static let bookIdsKey = "bookIds"
  private static let seriesIdsKey = "seriesIds"

  static func post(bookIds: Set<String>, seriesIds: Set<String>) async {
    await MainActor.run {
      NotificationCenter.default.post(
        name: .readerProgressDidSettle,
        object: nil,
        userInfo: [
          bookIdsKey: bookIds,
          seriesIdsKey: seriesIds,
        ]
      )
    }
  }
}
