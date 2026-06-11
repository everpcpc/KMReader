//
// SyncResult.swift
//
//

import Foundation

nonisolated struct SyncResult: Sendable {
  let hasFailures: Bool
  let readingProgressSynced: Bool
}
