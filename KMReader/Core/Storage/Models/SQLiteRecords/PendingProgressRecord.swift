//
// PendingProgressRecord.swift
//
//

import Foundation
import SQLiteData

@Table("pending_progress")
nonisolated struct PendingProgressRecord: Identifiable, Hashable, Sendable {
  let id: String
  var instanceId: String
  var bookId: String
  var page: Int
  var completed: Bool
  @Column(as: Date.UnixTimeRepresentation.self)
  var createdAt: Date
  var progressionData: Data?

  init(
    instanceId: String,
    bookId: String,
    page: Int,
    completed: Bool,
    progressionData: Data? = nil
  ) {
    self.id = UUID().uuidString
    self.instanceId = instanceId
    self.bookId = bookId
    self.page = page
    self.completed = completed
    self.createdAt = Date()
    self.progressionData = progressionData
  }
}
