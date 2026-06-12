//
// OfflineInstanceSyncInfo.swift
//
//

import Foundation

nonisolated struct OfflineInstanceSyncInfo: Equatable, Sendable {
  let instanceId: String
  let seriesLastSyncedAt: Date
  let booksLastSyncedAt: Date

  var latestSync: Date {
    max(seriesLastSyncedAt, booksLastSyncedAt)
  }
}
