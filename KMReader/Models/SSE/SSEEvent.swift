//
//  SSEEvent.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation

// MARK: - SSE Event Types

enum SSEEventType: String, Codable {
  case libraryAdded = "LibraryAdded"
  case libraryChanged = "LibraryChanged"
  case libraryDeleted = "LibraryDeleted"

  case seriesAdded = "SeriesAdded"
  case seriesChanged = "SeriesChanged"
  case seriesDeleted = "SeriesDeleted"

  case bookAdded = "BookAdded"
  case bookChanged = "BookChanged"
  case bookDeleted = "BookDeleted"
  case bookImported = "BookImported"

  case collectionAdded = "CollectionAdded"
  case collectionChanged = "CollectionChanged"
  case collectionDeleted = "CollectionDeleted"

  case readListAdded = "ReadListAdded"
  case readListChanged = "ReadListChanged"
  case readListDeleted = "ReadListDeleted"

  case readProgressChanged = "ReadProgressChanged"
  case readProgressDeleted = "ReadProgressDeleted"
  case readProgressSeriesChanged = "ReadProgressSeriesChanged"
  case readProgressSeriesDeleted = "ReadProgressSeriesDeleted"

  case thumbnailBookAdded = "ThumbnailBookAdded"
  case thumbnailBookDeleted = "ThumbnailBookDeleted"
  case thumbnailSeriesAdded = "ThumbnailSeriesAdded"
  case thumbnailSeriesDeleted = "ThumbnailSeriesDeleted"
  case thumbnailReadListAdded = "ThumbnailReadListAdded"
  case thumbnailReadListDeleted = "ThumbnailReadListDeleted"
  case thumbnailCollectionAdded = "ThumbnailSeriesCollectionAdded"
  case thumbnailCollectionDeleted = "ThumbnailSeriesCollectionDeleted"

  case taskQueueStatus = "TaskQueueStatus"
  case sessionExpired = "SessionExpired"
}

// MARK: - SSE Event Data Models

struct LibrarySSEDto: Codable {
  let libraryId: String
}

struct SeriesSSEDto: Codable {
  let seriesId: String
  let libraryId: String
}

struct BookSSEDto: Codable {
  let bookId: String
  let seriesId: String
  let libraryId: String
}

struct CollectionSSEDto: Codable {
  let collectionId: String
  let seriesIds: [String]
}

struct ReadListSSEDto: Codable {
  let readListId: String
  let bookIds: [String]
}

struct ReadProgressSSEDto: Codable {
  let bookId: String
  let userId: String
}

struct ReadProgressSeriesSSEDto: Codable {
  let seriesId: String
  let userId: String
}

struct ThumbnailBookSSEDto: Codable {
  let bookId: String
  let seriesId: String
  let selected: Bool
}

struct ThumbnailSeriesSSEDto: Codable {
  let seriesId: String
  let selected: Bool
}

struct ThumbnailReadListSSEDto: Codable {
  let readListId: String
  let selected: Bool
}

struct ThumbnailCollectionSSEDto: Codable {
  let collectionId: String
  let selected: Bool
}

struct SessionExpiredSSEDto: Codable {
  let userId: String
}

struct TaskQueueSSEDto: Codable {
  let count: Int
  let countByType: [String: Int]
}

struct BookImportSSEDto: Codable {
  let bookId: String?
  let sourceFile: String
  let success: Bool
  let message: String?
}
