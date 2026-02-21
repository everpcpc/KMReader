//
// KomgaCollectionRecord.swift
//
//

import Foundation
import SQLiteData

@Table("komga_collections")
nonisolated struct KomgaCollectionRecord: Identifiable, Hashable, Sendable {
  let id: String

  // API identifier (CollectionDto.id).
  var collectionId: String
  var instanceId: String

  // API scalar fields.
  var name: String
  var ordered: Bool
  @Column(as: Date.UnixTimeRepresentation.self)
  var createdDate: Date
  @Column(as: Date.UnixTimeRepresentation.self)
  var lastModifiedDate: Date
  var filtered: Bool

  // API array field persisted as JSON for SQLite storage.
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
    seriesIds: [String] = []
  ) {
    self.id = id ?? UUID().uuidString
    self.collectionId = collectionId
    self.instanceId = instanceId
    self.name = name
    self.ordered = ordered
    self.createdDate = createdDate
    self.lastModifiedDate = lastModifiedDate
    self.filtered = filtered
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

  func toKomgaCollection() -> KomgaCollection {
    KomgaCollection(
      id: id,
      collectionId: collectionId,
      instanceId: instanceId,
      name: name,
      ordered: ordered,
      createdDate: createdDate,
      lastModifiedDate: lastModifiedDate,
      filtered: filtered,
      seriesIds: seriesIds
    )
  }
}
