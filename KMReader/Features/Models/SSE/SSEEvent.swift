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

struct TaskQueueSSEDto: Codable, Equatable, RawRepresentable {
  typealias RawValue = String

  let count: Int
  let countByType: [String: Int]

  // MARK: - Codable
  enum CodingKeys: String, CodingKey {
    case count
    case countByType
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    count = try container.decode(Int.self, forKey: .count)
    countByType = try container.decode([String: Int].self, forKey: .countByType)
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(count, forKey: .count)
    try container.encode(countByType, forKey: .countByType)
  }

  // MARK: - RawRepresentable
  var rawValue: String {
    let dict: [String: Any] = [
      "count": count,
      "countByType": countByType,
    ]
    if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]),
      let json = String(data: data, encoding: .utf8)
    {
      return json
    }
    return "{}"
  }

  init?(rawValue: String) {
    guard !rawValue.isEmpty else {
      self.count = 0
      self.countByType = [:]
      return
    }
    guard let data = rawValue.data(using: .utf8),
      let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
      self.count = 0
      self.countByType = [:]
      return
    }
    self.count = dict["count"] as? Int ?? 0
    self.countByType = dict["countByType"] as? [String: Int] ?? [:]
  }

  // MARK: - Initializers
  init(count: Int = 0, countByType: [String: Int] = [:]) {
    self.count = count
    self.countByType = countByType
  }
}

struct BookImportSSEDto: Codable {
  let bookId: String?
  let sourceFile: String
  let success: Bool
  let message: String?
}
