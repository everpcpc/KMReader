//
// SavedFilterRecord.swift
//
//

import Foundation
import SQLiteData

@Table("saved_filters")
nonisolated struct SavedFilterRecord: Identifiable, Hashable, Sendable {
  let id: UUID
  var name: String
  var filterTypeRaw: String
  var filterDataJSON: String
  @Column(as: Date.UnixTimeRepresentation.self)
  var createdAt: Date
  @Column(as: Date.UnixTimeRepresentation.self)
  var updatedAt: Date
}

extension SavedFilterRecord {
  var filterType: SavedFilterType {
    SavedFilterType(rawValue: filterTypeRaw) ?? .series
  }

  func seriesOptions() -> SeriesBrowseOptions? {
    guard filterType == .series else { return nil }
    return SeriesBrowseOptions(rawValue: filterDataJSON)
  }

  func bookOptions() -> BookBrowseOptions? {
    guard filterType == .books || filterType == .seriesBooks else { return nil }
    return BookBrowseOptions(rawValue: filterDataJSON)
  }

  func collectionOptions() -> CollectionSeriesBrowseOptions? {
    guard filterType == .collectionSeries else { return nil }
    return CollectionSeriesBrowseOptions(rawValue: filterDataJSON)
  }

  func readListOptions() -> ReadListBookBrowseOptions? {
    guard filterType == .readListBooks else { return nil }
    return ReadListBookBrowseOptions(rawValue: filterDataJSON)
  }
}
