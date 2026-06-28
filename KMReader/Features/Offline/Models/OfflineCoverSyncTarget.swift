//
// OfflineCoverSyncTarget.swift
//
//

import Foundation

nonisolated struct OfflineCoverSyncTarget: Equatable, Identifiable, Sendable {
  let id: String
  let thumbnailId: String
  let type: ThumbnailType

  init(thumbnailId: String, type: ThumbnailType) {
    self.id = "\(type.rawValue):\(thumbnailId)"
    self.thumbnailId = thumbnailId
    self.type = type
  }
}
