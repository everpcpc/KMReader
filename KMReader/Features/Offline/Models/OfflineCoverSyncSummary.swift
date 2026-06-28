//
// OfflineCoverSyncSummary.swift
//
//

import Foundation

nonisolated struct OfflineCoverSyncSummary: Equatable, Sendable {
  var totalCount = 0
  var checkedCount = 0
  var existingCount = 0
  var storedCount = 0
  var failedCount = 0
  var stoppedAtCacheLimit = false
  var wasCancelled = false

  var missingCount: Int {
    storedCount + failedCount
  }
}
