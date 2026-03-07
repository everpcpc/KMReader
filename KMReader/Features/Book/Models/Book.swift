//
// Book.swift
//
//

import Foundation
import UniformTypeIdentifiers

nonisolated struct Book: Codable, Identifiable, Equatable, Sendable {
  let id: String
  let seriesId: String
  let seriesTitle: String
  let libraryId: String
  let name: String
  let url: String
  let number: Double
  let created: Date
  let lastModified: Date
  let sizeBytes: Int64
  let size: String
  let media: Media
  let metadata: BookMetadata
  let readProgress: ReadProgress?
  let deleted: Bool
  let fileHash: String?
  let oneshot: Bool

  var hasStartedReading: Bool {
    readProgress != nil
  }

  var isUnread: Bool {
    !hasStartedReading
  }

  var isCompleted: Bool {
    readProgress?.completed == true
  }

  var isInProgress: Bool {
    hasStartedReading && !isCompleted
  }
}
