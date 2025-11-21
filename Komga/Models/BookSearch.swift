//
//  BookSearch.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation

enum ReadStatus: String, Codable {
  case unread = "UNREAD"
  case inProgress = "IN_PROGRESS"
  case read = "READ"
}

// Simplified search structure that can encode to the correct JSON format
struct BookSearch: Encodable {
  enum Condition {
    case readStatus(ReadStatus)
    case libraryIdAndReadStatus(libraryId: String, readStatus: ReadStatus)
    case libraryId(String)
    case seriesId(String)
    case readListId(String)
    case allOf([Condition])  // AllOf condition - empty array means match all books
  }

  let condition: Condition
  let fullTextSearch: String?

  init(condition: Condition, fullTextSearch: String? = nil) {
    self.condition = condition
    self.fullTextSearch = fullTextSearch
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    switch condition {
    case .readStatus(let status):
      // Encode as: { "condition": { "readStatus": { "operator": "is", "value": "IN_PROGRESS" } } }
      var conditionContainer = container.nestedContainer(
        keyedBy: ReadStatusKeys.self, forKey: .condition)
      var readStatusContainer = conditionContainer.nestedContainer(
        keyedBy: OperatorKeys.self, forKey: .readStatus)
      try readStatusContainer.encode("is", forKey: .operator)
      try readStatusContainer.encode(status.rawValue, forKey: .value)

    case .libraryIdAndReadStatus(let libraryId, let status):
      // Encode as: { "condition": { "allOf": [...] } }
      var conditionContainer = container.nestedContainer(
        keyedBy: AllOfKeys.self, forKey: .condition)
      var allOfContainer = conditionContainer.nestedUnkeyedContainer(forKey: .allOf)

      // Library condition
      var libraryContainer = allOfContainer.nestedContainer(keyedBy: LibraryIdKeys.self)
      var libraryOperatorContainer = libraryContainer.nestedContainer(
        keyedBy: OperatorKeys.self, forKey: .libraryId)
      try libraryOperatorContainer.encode("is", forKey: .operator)
      try libraryOperatorContainer.encode(libraryId, forKey: .value)

      // ReadStatus condition
      var statusContainer = allOfContainer.nestedContainer(keyedBy: ReadStatusKeys.self)
      var statusOperatorContainer = statusContainer.nestedContainer(
        keyedBy: OperatorKeys.self, forKey: .readStatus)
      try statusOperatorContainer.encode("is", forKey: .operator)
      try statusOperatorContainer.encode(status.rawValue, forKey: .value)

    case .libraryId(let libraryId):
      // Encode as: { "condition": { "libraryId": { "operator": "is", "value": "..." } } }
      var conditionContainer = container.nestedContainer(
        keyedBy: LibraryIdKeys.self, forKey: .condition)
      var libraryIdContainer = conditionContainer.nestedContainer(
        keyedBy: OperatorKeys.self, forKey: .libraryId)
      try libraryIdContainer.encode("is", forKey: .operator)
      try libraryIdContainer.encode(libraryId, forKey: .value)

    case .seriesId(let seriesId):
      // Encode as: { "condition": { "seriesId": { "operator": "is", "value": "..." } } }
      var conditionContainer = container.nestedContainer(
        keyedBy: SeriesIdKeys.self, forKey: .condition)
      var seriesIdContainer = conditionContainer.nestedContainer(
        keyedBy: OperatorKeys.self, forKey: .seriesId)
      try seriesIdContainer.encode("is", forKey: .operator)
      try seriesIdContainer.encode(seriesId, forKey: .value)

    case .readListId(let readListId):
      // Encode as: { "condition": { "readListId": { "operator": "is", "value": "..." } } }
      var conditionContainer = container.nestedContainer(
        keyedBy: ReadListIdKeys.self, forKey: .condition)
      var readListIdContainer = conditionContainer.nestedContainer(
        keyedBy: OperatorKeys.self, forKey: .readListId)
      try readListIdContainer.encode("is", forKey: .operator)
      try readListIdContainer.encode(readListId, forKey: .value)

    case .allOf(let conditions):
      // Encode as: { "condition": { "allOf": [...] } }
      // Empty array means match all books
      var conditionContainer = container.nestedContainer(
        keyedBy: AllOfKeys.self, forKey: .condition)
      var allOfContainer = conditionContainer.nestedUnkeyedContainer(forKey: .allOf)

      // Encode each condition in the array
      for condition in conditions {
        try encodeCondition(condition, into: &allOfContainer)
      }

      try container.encodeIfPresent(fullTextSearch, forKey: .fullTextSearch)
    }
  }

  private enum CodingKeys: String, CodingKey {
    case condition
    case fullTextSearch
  }

  private enum AllOfKeys: String, CodingKey {
    case allOf
  }

  private enum LibraryIdKeys: String, CodingKey {
    case libraryId
  }

  private enum ReadStatusKeys: String, CodingKey {
    case readStatus
  }

  private enum SeriesIdKeys: String, CodingKey {
    case seriesId
  }

  private enum ReadListIdKeys: String, CodingKey {
    case readListId
  }

  private enum OperatorKeys: String, CodingKey {
    case `operator`
    case value
  }

  // Helper method to encode a condition into an unkeyed container (for allOf array)
  private func encodeCondition(
    _ condition: Condition, into container: inout UnkeyedEncodingContainer
  ) throws {
    switch condition {
    case .readStatus(let status):
      var statusContainer = container.nestedContainer(keyedBy: ReadStatusKeys.self)
      var statusOperatorContainer = statusContainer.nestedContainer(
        keyedBy: OperatorKeys.self, forKey: .readStatus)
      try statusOperatorContainer.encode("is", forKey: .operator)
      try statusOperatorContainer.encode(status.rawValue, forKey: .value)

    case .libraryId(let libraryId):
      var libraryContainer = container.nestedContainer(keyedBy: LibraryIdKeys.self)
      var libraryOperatorContainer = libraryContainer.nestedContainer(
        keyedBy: OperatorKeys.self, forKey: .libraryId)
      try libraryOperatorContainer.encode("is", forKey: .operator)
      try libraryOperatorContainer.encode(libraryId, forKey: .value)

    case .libraryIdAndReadStatus(let libraryId, let status):
      // For allOf, we need to encode this as two separate conditions
      // First, libraryId
      var libraryContainer = container.nestedContainer(keyedBy: LibraryIdKeys.self)
      var libraryOperatorContainer = libraryContainer.nestedContainer(
        keyedBy: OperatorKeys.self, forKey: .libraryId)
      try libraryOperatorContainer.encode("is", forKey: .operator)
      try libraryOperatorContainer.encode(libraryId, forKey: .value)

      // Then, readStatus
      var statusContainer = container.nestedContainer(keyedBy: ReadStatusKeys.self)
      var statusOperatorContainer = statusContainer.nestedContainer(
        keyedBy: OperatorKeys.self, forKey: .readStatus)
      try statusOperatorContainer.encode("is", forKey: .operator)
      try statusOperatorContainer.encode(status.rawValue, forKey: .value)

    case .seriesId(let seriesId):
      var seriesContainer = container.nestedContainer(keyedBy: SeriesIdKeys.self)
      var seriesOperatorContainer = seriesContainer.nestedContainer(
        keyedBy: OperatorKeys.self, forKey: .seriesId)
      try seriesOperatorContainer.encode("is", forKey: .operator)
      try seriesOperatorContainer.encode(seriesId, forKey: .value)

    case .readListId(let readListId):
      var readListContainer = container.nestedContainer(keyedBy: ReadListIdKeys.self)
      var readListOperatorContainer = readListContainer.nestedContainer(
        keyedBy: OperatorKeys.self, forKey: .readListId)
      try readListOperatorContainer.encode("is", forKey: .operator)
      try readListOperatorContainer.encode(readListId, forKey: .value)

    case .allOf(let nestedConditions):
      // Nested allOf - encode recursively
      for nestedCondition in nestedConditions {
        try encodeCondition(nestedCondition, into: &container)
      }
    }
  }
}
