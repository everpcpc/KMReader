//
//  SeriesSortField.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation

enum SeriesSortField: String, CaseIterable {
  case name = "metadata.titleSort"
  case dateAdded = "created"
  case dateUpdated = "lastModified"
  case dateRead = "fileLastModified"
  case releaseDate = "booksMetadata.releaseDate"
  case downloadDate = "downloadAt"
  case folderName = "metadata.title"
  case booksCount = "booksCount"
  case random = "random"

  var displayName: String {
    switch self {
    case .name: return String(localized: "series.sortField.name")
    case .dateAdded: return String(localized: "series.sortField.dateAdded")
    case .dateUpdated: return String(localized: "series.sortField.dateUpdated")
    case .dateRead: return String(localized: "series.sortField.dateRead")
    case .releaseDate: return String(localized: "series.sortField.releaseDate")
    case .downloadDate: return String(localized: "series.sortField.downloadDate")
    case .folderName: return String(localized: "series.sortField.folderName")
    case .booksCount: return String(localized: "series.sortField.booksCount")
    case .random: return String(localized: "series.sortField.random")
    }
  }

  static var onlineCases: [SeriesSortField] {
    allCases.filter { $0 != .downloadDate }
  }

  static var offlineCases: [SeriesSortField] {
    Array(allCases)
  }

  var supportsDirection: Bool {
    self != .random
  }
}
