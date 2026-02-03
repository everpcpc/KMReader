//
//  BookSortField.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation

// Sort field enum for Books
enum BookSortField: String, CaseIterable {
  case series = "series,metadata.numberSort"
  case name = "metadata.title"
  case dateAdded = "createdDate"
  case dateUpdated = "lastModifiedDate"
  case releaseDate = "metadata.releaseDate"
  case dateRead = "readProgress.readDate"
  case fileSize = "fileSize"
  case fileName = "name"
  case pageCount = "media.pagesCount"

  var displayName: String {
    switch self {
    case .series: return String(localized: "bookSort.series")
    case .name: return String(localized: "bookSort.name")
    case .dateAdded: return String(localized: "bookSort.dateAdded")
    case .dateUpdated: return String(localized: "bookSort.dateUpdated")
    case .releaseDate: return String(localized: "bookSort.releaseDate")
    case .dateRead: return String(localized: "bookSort.dateRead")
    case .fileSize: return String(localized: "bookSort.fileSize")
    case .fileName: return String(localized: "bookSort.fileName")
    case .pageCount: return String(localized: "bookSort.pageCount")
    }
  }

  var supportsDirection: Bool {
    return true
  }
}
