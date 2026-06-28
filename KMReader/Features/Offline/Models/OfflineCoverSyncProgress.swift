//
// OfflineCoverSyncProgress.swift
//
//

import Foundation

nonisolated struct OfflineCoverSyncProgress: Equatable, Sendable {
  let totalCount: Int
  let checkedCount: Int
  let existingCount: Int
  let storedCount: Int
  let failedCount: Int

  static let empty = OfflineCoverSyncProgress(
    totalCount: 0,
    checkedCount: 0,
    existingCount: 0,
    storedCount: 0,
    failedCount: 0
  )

  var progressFraction: Double {
    guard totalCount > 0 else { return 0 }
    return min(1, Double(checkedCount) / Double(totalCount))
  }
}
