//
// KomgaCollection.swift
//
//

import Foundation
import SwiftData

@Model
final class KomgaCollection {
  @Attribute(.unique) var id: String  // Composite: CompositeID.generate

  var collectionId: String
  var instanceId: String

  var name: String
  var ordered: Bool
  var createdDate: Date
  var lastModifiedDate: Date
  var filtered: Bool
  var isPinned: Bool = false

  var seriesIdsRaw: Data?

  var seriesIds: [String] {
    get { seriesIdsRaw.flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? [] }
    set { seriesIdsRaw = try? JSONEncoder().encode(newValue) }
  }

  init(
    id: String? = nil,
    collectionId: String,
    instanceId: String,
    name: String,
    ordered: Bool,
    createdDate: Date,
    lastModifiedDate: Date,
    filtered: Bool,
    isPinned: Bool = false,
    seriesIds: [String] = []
  ) {
    self.id = id ?? CompositeID.generate(instanceId: instanceId, id: collectionId)
    self.collectionId = collectionId
    self.instanceId = instanceId
    self.name = name
    self.ordered = ordered
    self.createdDate = createdDate
    self.lastModifiedDate = lastModifiedDate
    self.filtered = filtered
    self.isPinned = isPinned
    self.seriesIdsRaw = try? JSONEncoder().encode(seriesIds)
  }

  func toCollection() -> SeriesCollection {
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
