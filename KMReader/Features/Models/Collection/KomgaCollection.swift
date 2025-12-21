//
//  KomgaCollection.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftData

@Model
final class KomgaCollection {
  @Attribute(.unique) var id: String  // Composite ID: "\(instanceId)_\(collectionId)"

  var collectionId: String
  var instanceId: String

  var name: String
  var ordered: Bool
  var createdDate: Date
  var lastModifiedDate: Date
  var filtered: Bool

  var seriesIds: [String] = []

  init(
    id: String? = nil,
    collectionId: String,
    instanceId: String,
    name: String,
    ordered: Bool,
    createdDate: Date,
    lastModifiedDate: Date,
    filtered: Bool,
    seriesIds: [String] = []
  ) {
    self.id = id ?? "\(instanceId)_\(collectionId)"
    self.collectionId = collectionId
    self.instanceId = instanceId
    self.name = name
    self.ordered = ordered
    self.createdDate = createdDate
    self.lastModifiedDate = lastModifiedDate
    self.filtered = filtered
    self.seriesIds = seriesIds
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
