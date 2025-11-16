//
//  Series.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation

struct Series: Codable, Identifiable, Equatable {
  let id: String
  let libraryId: String
  let name: String
  let url: String
  let created: Date
  let lastModified: Date
  let booksCount: Int
  let booksReadCount: Int
  let booksUnreadCount: Int
  let booksInProgressCount: Int
  let metadata: SeriesMetadata
  let booksMetadata: SeriesBooksMetadata
  let deleted: Bool
  let oneshot: Bool
}

struct SeriesMetadata: Codable, Equatable {
  let status: String?
  let statusLock: Bool?
  let created: String?
  let lastModified: String?
  let title: String
  let titleLock: Bool?
  let titleSort: String
  let titleSortLock: Bool?
  let summary: String?
  let summaryLock: Bool?
  let readingDirection: String?
  let readingDirectionLock: Bool?
  let publisher: String?
  let publisherLock: Bool?
  let ageRating: Int?
  let ageRatingLock: Bool?
  let language: String?
  let languageLock: Bool?
  let genres: [String]?
  let genresLock: Bool?
  let tags: [String]?
  let tagsLock: Bool?
  let totalBookCount: Int?
  let totalBookCountLock: Bool?
  let sharingLabels: [String]?
  let sharingLabelsLock: Bool?
  let links: [WebLink]?
  let linksLock: Bool?
  let alternateTitles: [AlternateTitle]?
  let alternateTitlesLock: Bool?
}

struct SeriesBooksMetadata: Codable, Equatable {
  let created: String?
  let lastModified: String?
  let authors: [Author]?
  let tags: [String]?
  let releaseDate: String?
  let summary: String?
  let summaryNumber: String?
}

struct AlternateTitle: Codable, Equatable {
  let label: String
  let title: String
}

// Filter and Sort enums for Series
enum ReadStatusFilter: String, CaseIterable {
  case all = "ALL"
  case read = "READ"
  case unread = "UNREAD"
  case inProgress = "IN_PROGRESS"

  var displayName: String {
    switch self {
    case .all: return "All"
    case .read: return "Read"
    case .unread: return "Unread"
    case .inProgress: return "In Progress"
    }
  }
}

enum SeriesStatusFilter: String, CaseIterable {
  case all = "ALL"
  case ongoing = "ONGOING"
  case ended = "ENDED"
  case hiatus = "HIATUS"
  case cancelled = "CANCELLED"

  var displayName: String {
    switch self {
    case .all: return "All"
    case .ongoing: return "Ongoing"
    case .ended: return "Ended"
    case .hiatus: return "Hiatus"
    case .cancelled: return "Cancelled"
    }
  }
}

enum SeriesSortField: String, CaseIterable {
  case name = "metadata.titleSort"
  case dateAdded = "created"
  case dateUpdated = "lastModified"
  case dateRead = "fileLastModified"
  case releaseDate = "booksMetadata.releaseDate"
  case folderName = "metadata.title"
  case booksCount = "booksCount"
  case random = "random"

  var displayName: String {
    switch self {
    case .name: return "Name"
    case .dateAdded: return "Date Added"
    case .dateUpdated: return "Date Updated"
    case .dateRead: return "Date Read"
    case .releaseDate: return "Release Date"
    case .folderName: return "Folder Name"
    case .booksCount: return "Books Count"
    case .random: return "Random"
    }
  }

  var supportsDirection: Bool {
    return self != .random
  }
}

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
    case .nameAsc: return "Name (A-Z)"
    case .nameDesc: return "Name (Z-A)"
    case .dateAddedAsc: return "Date Added (Oldest)"
    case .dateAddedDesc: return "Date Added (Newest)"
    case .dateUpdatedAsc: return "Date Updated (Oldest)"
    case .dateUpdatedDesc: return "Date Updated (Newest)"
    case .dateReadAsc: return "Date Read (Oldest)"
    case .dateReadDesc: return "Date Read (Newest)"
    case .releaseDateAsc: return "Release Date (Oldest)"
    case .releaseDateDesc: return "Release Date (Newest)"
    case .folderNameAsc: return "Folder Name (A-Z)"
    case .folderNameDesc: return "Folder Name (Z-A)"
    case .booksCountAsc: return "Books Count (Fewest)"
    case .booksCountDesc: return "Books Count (Most)"
    case .random: return "Random"
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
