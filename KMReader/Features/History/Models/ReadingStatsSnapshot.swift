//
// ReadingStatsSnapshot.swift
//
//

import Foundation

nonisolated struct ReadingStatsSnapshot: Codable, Equatable, Sendable {
  let libraryId: String
  let cachedAt: Date
  let payload: ReadingStatsPayload

  init(libraryId: String, cachedAt: Date, payload: ReadingStatsPayload) {
    self.libraryId = libraryId
    self.cachedAt = cachedAt
    self.payload = payload
  }
}
