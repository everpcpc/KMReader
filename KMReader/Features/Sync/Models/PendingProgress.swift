//
// PendingProgress.swift
//

import Foundation

nonisolated struct PendingProgress: Codable, Equatable, Sendable {
  var id: String
  var instanceId: String
  var bookId: String
  var page: Int
  var completed: Bool
  var createdAt: Date
  var progressionData: Data?

  init(
    instanceId: String,
    bookId: String,
    page: Int,
    completed: Bool,
    progressionData: Data? = nil,
    createdAt: Date = Date()
  ) {
    self.id = CompositeID.generate(instanceId: instanceId, id: bookId)
    self.instanceId = instanceId
    self.bookId = bookId
    self.page = page
    self.completed = completed
    self.createdAt = createdAt
    self.progressionData = progressionData
  }
}
