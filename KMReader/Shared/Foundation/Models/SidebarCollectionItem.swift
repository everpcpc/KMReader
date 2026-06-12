//
// SidebarCollectionItem.swift
//
//

import Foundation

nonisolated struct SidebarCollectionItem: Hashable, Identifiable, Sendable {
  let id: String
  let collectionId: String
  let name: String
  let seriesCount: Int

  init(collectionId: String, name: String, seriesCount: Int) {
    id = collectionId
    self.collectionId = collectionId
    self.name = name
    self.seriesCount = seriesCount
  }
}
