//
// PendingProgress.swift
//
//

import Foundation
import SwiftData

@Model
final class PendingProgress {
  @Attribute(.unique) var id: String

  var instanceId: String
  var bookId: String
  var page: Int
  var completed: Bool
  var createdAt: Date
  var progressionData: Data?  // For EPUB R2Progression

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
