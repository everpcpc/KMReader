//
//  SavedFilter.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftData

enum SavedFilterType: String, CaseIterable, Identifiable {
  case series
  case books
  case collectionSeries
  case readListBooks
  case seriesBooks

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .series: return String(localized: "browse.content.series")
    case .books: return String(localized: "browse.content.books")
    case .collectionSeries:
      return String(localized: "browse.content.collections") + " - "
        + String(localized: "browse.content.series")
    case .readListBooks:
      return String(localized: "browse.content.readlists") + " - "
        + String(localized: "browse.content.books")
    case .seriesBooks:
      return String(localized: "browse.content.series") + " - "
        + String(localized: "browse.content.books")
    }
  }
}

typealias SavedFilter = SavedFilterV1

@Model
final class SavedFilterV1 {
  @Attribute(.unique) var id: UUID

  var name: String
  var filterTypeRaw: String
  var filterDataJSON: String
  var createdAt: Date
  var updatedAt: Date

  var filterType: SavedFilterType {
    get {
      SavedFilterType(rawValue: filterTypeRaw) ?? .series
    }
    set {
      filterTypeRaw = newValue.rawValue
    }
  }

  init(
    id: UUID = UUID(),
    name: String,
    filterType: SavedFilterType,
    filterDataJSON: String,
    createdAt: Date = Date(),
    updatedAt: Date = Date()
  ) {
    self.id = id
    self.name = name
    self.filterTypeRaw = filterType.rawValue
    self.filterDataJSON = filterDataJSON
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  @MainActor
  func getSeriesBrowseOptions() -> SeriesBrowseOptions? {
    guard filterType == .series else { return nil }
    return SeriesBrowseOptions(rawValue: filterDataJSON)
  }

  @MainActor
  func getBookBrowseOptions() -> BookBrowseOptions? {
    guard filterType == .books || filterType == .seriesBooks else { return nil }
    return BookBrowseOptions(rawValue: filterDataJSON)
  }

  @MainActor
  func getCollectionSeriesBrowseOptions() -> CollectionSeriesBrowseOptions? {
    guard filterType == .collectionSeries else { return nil }
    return CollectionSeriesBrowseOptions(rawValue: filterDataJSON)
  }

  @MainActor
  func getReadListBookBrowseOptions() -> ReadListBookBrowseOptions? {
    guard filterType == .readListBooks else { return nil }
    return ReadListBookBrowseOptions(rawValue: filterDataJSON)
  }

  @MainActor
  static func create(
    name: String,
    filterType: SavedFilterType,
    seriesOptions: SeriesBrowseOptions? = nil,
    bookOptions: BookBrowseOptions? = nil,
    collectionOptions: CollectionSeriesBrowseOptions? = nil,
    readListOptions: ReadListBookBrowseOptions? = nil
  ) -> SavedFilter? {
    let filterJSON: String

    switch filterType {
    case .series:
      guard let options = seriesOptions else { return nil }
      filterJSON = options.rawValue
    case .books, .seriesBooks:
      guard let options = bookOptions else { return nil }
      filterJSON = options.rawValue
    case .collectionSeries:
      guard let options = collectionOptions else { return nil }
      filterJSON = options.rawValue
    case .readListBooks:
      guard let options = readListOptions else { return nil }
      filterJSON = options.rawValue
    }

    return SavedFilter(
      name: name,
      filterType: filterType,
      filterDataJSON: filterJSON
    )
  }
}
