//
// CollectionDisplayItem.swift
//
//

import Foundation

nonisolated struct CollectionDisplayItem: Equatable, Identifiable, Sendable {
  let id: String
  let collectionId: String
  let instanceId: String
  let name: String
  let ordered: Bool
  let createdDate: Date
  let lastModifiedDate: Date
  let filtered: Bool
  let isPinned: Bool
  let seriesIds: [String]

  init(
    collectionId: String,
    instanceId: String,
    name: String,
    ordered: Bool,
    createdDate: Date,
    lastModifiedDate: Date,
    filtered: Bool,
    isPinned: Bool,
    seriesIds: [String]
  ) {
    id = collectionId
    self.collectionId = collectionId
    self.instanceId = instanceId
    self.name = name
    self.ordered = ordered
    self.createdDate = createdDate
    self.lastModifiedDate = lastModifiedDate
    self.filtered = filtered
    self.isPinned = isPinned
    self.seriesIds = seriesIds
  }

  var seriesCount: Int {
    seriesIds.count
  }

  var collection: SeriesCollection {
    SeriesCollection(
      id: collectionId,
      name: name,
      ordered: ordered,
      seriesIds: seriesIds,
      createdDate: createdDate,
      lastModifiedDate: lastModifiedDate,
      filtered: filtered
    )
  }
}
