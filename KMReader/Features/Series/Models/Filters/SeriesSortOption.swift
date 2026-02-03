//
//  SeriesSortOption.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation

// Legacy enum for backward compatibility - converts to new format
enum SeriesSortOption: String, CaseIterable {
  case nameAsc = "metadata.titleSort,asc"
  case nameDesc = "metadata.titleSort,desc"
  case dateAddedAsc = "created,asc"
  case dateAddedDesc = "created,desc"
  case dateUpdatedAsc = "lastModified,asc"
  case dateUpdatedDesc = "lastModified,desc"
  case dateReadAsc = "fileLastModified,asc"
  case dateReadDesc = "fileLastModified,desc"
  case releaseDateAsc = "booksMetadata.releaseDate,asc"
  case releaseDateDesc = "booksMetadata.releaseDate,desc"
  case folderNameAsc = "metadata.title,asc"
  case folderNameDesc = "metadata.title,desc"
  case booksCountAsc = "booksCount,asc"
  case booksCountDesc = "booksCount,desc"
  case random = "random"

  var displayName: String {
    switch self {
    case .nameAsc: return String(localized: "series.sortOption.nameAsc")
    case .nameDesc: return String(localized: "series.sortOption.nameDesc")
    case .dateAddedAsc: return String(localized: "series.sortOption.dateAddedAsc")
    case .dateAddedDesc: return String(localized: "series.sortOption.dateAddedDesc")
    case .dateUpdatedAsc: return String(localized: "series.sortOption.dateUpdatedAsc")
    case .dateUpdatedDesc: return String(localized: "series.sortOption.dateUpdatedDesc")
    case .dateReadAsc: return String(localized: "series.sortOption.dateReadAsc")
    case .dateReadDesc: return String(localized: "series.sortOption.dateReadDesc")
    case .releaseDateAsc: return String(localized: "series.sortOption.releaseDateAsc")
    case .releaseDateDesc: return String(localized: "series.sortOption.releaseDateDesc")
    case .folderNameAsc: return String(localized: "series.sortOption.folderNameAsc")
    case .folderNameDesc: return String(localized: "series.sortOption.folderNameDesc")
    case .booksCountAsc: return String(localized: "series.sortOption.booksCountAsc")
    case .booksCountDesc: return String(localized: "series.sortOption.booksCountDesc")
    case .random: return String(localized: "series.sortOption.random")
    }
  }

  var sortField: SeriesSortField {
    switch self {
    case .nameAsc, .nameDesc: return .name
    case .dateAddedAsc, .dateAddedDesc: return .dateAdded
    case .dateUpdatedAsc, .dateUpdatedDesc: return .dateUpdated
    case .dateReadAsc, .dateReadDesc: return .dateRead
    case .releaseDateAsc, .releaseDateDesc: return .releaseDate
    case .folderNameAsc, .folderNameDesc: return .folderName
    case .booksCountAsc, .booksCountDesc: return .booksCount
    case .random: return .random
    }
  }

  var sortDirection: SortDirection {
    switch self {
    case .nameAsc, .dateAddedAsc, .dateUpdatedAsc, .dateReadAsc, .releaseDateAsc, .folderNameAsc,
      .booksCountAsc:
      return .ascending
    case .nameDesc, .dateAddedDesc, .dateUpdatedDesc, .dateReadDesc, .releaseDateDesc,
      .folderNameDesc, .booksCountDesc:
      return .descending
    case .random: return .ascending  // Not used for random
    }
  }
}
