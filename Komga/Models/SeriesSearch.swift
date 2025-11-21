//
//  SeriesSearch.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation

// Simplified search structure that can encode to the correct JSON format for series list API
struct SeriesSearch: Encodable {
  enum Condition {
    case readStatus(ReadStatus)
    case libraryIdAndReadStatus(libraryId: String, readStatus: ReadStatus)
    case libraryId(String)
    case seriesStatus(String)  // metadata.status: ONGOING, ENDED, HIATUS, CANCELLED
    case libraryIdAndSeriesStatus(libraryId: String, seriesStatus: String)
    case readStatusAndSeriesStatus(readStatus: ReadStatus, seriesStatus: String)
    case collectionId(String)
    case allOf([Condition])  // AllOf condition - empty array means match all series
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
      // Encode as: { "condition": { "anyOf": [{"readStatus": {"operator": "is", "value": "READ"}}] } } }
      // For series, readStatus is wrapped in anyOf array
      var conditionContainer = container.nestedContainer(
        keyedBy: AnyOfKeys.self, forKey: .condition)
      var anyOfContainer = conditionContainer.nestedUnkeyedContainer(forKey: .anyOf)
      var readStatusItemContainer = anyOfContainer.nestedContainer(keyedBy: ReadStatusKeys.self)
      var readStatusContainer = readStatusItemContainer.nestedContainer(
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

      // ReadStatus condition - wrap in anyOf
      var anyOfContainer = allOfContainer.nestedContainer(keyedBy: AnyOfKeys.self)
      var anyOfArrayContainer = anyOfContainer.nestedUnkeyedContainer(forKey: .anyOf)
      var readStatusItemContainer = anyOfArrayContainer.nestedContainer(
        keyedBy: ReadStatusKeys.self)
      var readStatusOperatorContainer = readStatusItemContainer.nestedContainer(
        keyedBy: OperatorKeys.self, forKey: .readStatus)
      try readStatusOperatorContainer.encode("is", forKey: .operator)
      try readStatusOperatorContainer.encode(status.rawValue, forKey: .value)

    case .libraryId(let libraryId):
      // Encode as: { "condition": { "libraryId": { "operator": "is", "value": "..." } } }
      var conditionContainer = container.nestedContainer(
        keyedBy: LibraryIdKeys.self, forKey: .condition)
      var libraryIdContainer = conditionContainer.nestedContainer(
        keyedBy: OperatorKeys.self, forKey: .libraryId)
      try libraryIdContainer.encode("is", forKey: .operator)
      try libraryIdContainer.encode(libraryId, forKey: .value)

    case .seriesStatus(let status):
      // Encode as: { "condition": { "anyOf": [{"seriesStatus": {"operator": "is", "value": "ONGOING"}}] } } }
      var conditionContainer = container.nestedContainer(
        keyedBy: AnyOfKeys.self, forKey: .condition)
      var anyOfContainer = conditionContainer.nestedUnkeyedContainer(forKey: .anyOf)
      var seriesStatusItemContainer = anyOfContainer.nestedContainer(keyedBy: SeriesStatusKeys.self)
      var seriesStatusContainer = seriesStatusItemContainer.nestedContainer(
        keyedBy: OperatorKeys.self, forKey: .seriesStatus)
      try seriesStatusContainer.encode("is", forKey: .operator)
      try seriesStatusContainer.encode(status, forKey: .value)

    case .libraryIdAndSeriesStatus(let libraryId, let status):
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

      // SeriesStatus condition - wrap in anyOf
      var anyOfContainer = allOfContainer.nestedContainer(keyedBy: AnyOfKeys.self)
      var anyOfArrayContainer = anyOfContainer.nestedUnkeyedContainer(forKey: .anyOf)
      var seriesStatusItemContainer = anyOfArrayContainer.nestedContainer(
        keyedBy: SeriesStatusKeys.self)
      var statusOperatorContainer = seriesStatusItemContainer.nestedContainer(
        keyedBy: OperatorKeys.self, forKey: .seriesStatus)
      try statusOperatorContainer.encode("is", forKey: .operator)
      try statusOperatorContainer.encode(status, forKey: .value)

    case .readStatusAndSeriesStatus(let readStatus, let seriesStatus):
      // Encode as: { "condition": { "allOf": [...] } }
      var conditionContainer = container.nestedContainer(
        keyedBy: AllOfKeys.self, forKey: .condition)
      var allOfContainer = conditionContainer.nestedUnkeyedContainer(forKey: .allOf)

      // ReadStatus condition - wrap in anyOf
      var readStatusAnyOfContainer = allOfContainer.nestedContainer(keyedBy: AnyOfKeys.self)
      var readStatusAnyOfArrayContainer = readStatusAnyOfContainer.nestedUnkeyedContainer(
        forKey: .anyOf)
      var readStatusItemContainer = readStatusAnyOfArrayContainer.nestedContainer(
        keyedBy: ReadStatusKeys.self)
      var readStatusOperatorContainer = readStatusItemContainer.nestedContainer(
        keyedBy: OperatorKeys.self, forKey: .readStatus)
      try readStatusOperatorContainer.encode("is", forKey: .operator)
      try readStatusOperatorContainer.encode(readStatus.rawValue, forKey: .value)

      // SeriesStatus condition - wrap in anyOf
      var anyOfContainer = allOfContainer.nestedContainer(keyedBy: AnyOfKeys.self)
      var anyOfArrayContainer = anyOfContainer.nestedUnkeyedContainer(forKey: .anyOf)
      var seriesStatusItemContainer = anyOfArrayContainer.nestedContainer(
        keyedBy: SeriesStatusKeys.self)
      var seriesStatusOperatorContainer = seriesStatusItemContainer.nestedContainer(
        keyedBy: OperatorKeys.self, forKey: .seriesStatus)
      try seriesStatusOperatorContainer.encode("is", forKey: .operator)
      try seriesStatusOperatorContainer.encode(seriesStatus, forKey: .value)

    case .collectionId(let collectionId):
      // Encode as: { "condition": { "collectionId": { "operator": "is", "value": "..." } } }
      var conditionContainer = container.nestedContainer(
        keyedBy: CollectionIdKeys.self, forKey: .condition)
      var collectionIdContainer = conditionContainer.nestedContainer(
        keyedBy: OperatorKeys.self, forKey: .collectionId)
      try collectionIdContainer.encode("is", forKey: .operator)
      try collectionIdContainer.encode(collectionId, forKey: .value)

    case .allOf(let conditions):
      // Encode as: { "condition": { "allOf": [...] } }
      // Empty array means match all series
      var conditionContainer = container.nestedContainer(
        keyedBy: AllOfKeys.self, forKey: .condition)
      var allOfContainer = conditionContainer.nestedUnkeyedContainer(forKey: .allOf)

      // Encode each condition in the array
      for condition in conditions {
        try encodeCondition(condition, into: &allOfContainer)
      }
    }

    try container.encodeIfPresent(fullTextSearch, forKey: .fullTextSearch)
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

  private enum SeriesStatusKeys: String, CodingKey {
    case seriesStatus
  }

  private enum CollectionIdKeys: String, CodingKey {
    case collectionId
  }

  private enum AnyOfKeys: String, CodingKey {
    case anyOf
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
      // Wrap in anyOf array
      var anyOfContainer = container.nestedContainer(keyedBy: AnyOfKeys.self)
      var anyOfArrayContainer = anyOfContainer.nestedUnkeyedContainer(forKey: .anyOf)
      var readStatusItemContainer = anyOfArrayContainer.nestedContainer(
        keyedBy: ReadStatusKeys.self)
      var readStatusOperatorContainer = readStatusItemContainer.nestedContainer(
        keyedBy: OperatorKeys.self, forKey: .readStatus)
      try readStatusOperatorContainer.encode("is", forKey: .operator)
      try readStatusOperatorContainer.encode(status.rawValue, forKey: .value)

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

      // Then, readStatus - wrap in anyOf
      var anyOfContainer = container.nestedContainer(keyedBy: AnyOfKeys.self)
      var anyOfArrayContainer = anyOfContainer.nestedUnkeyedContainer(forKey: .anyOf)
      var readStatusItemContainer = anyOfArrayContainer.nestedContainer(
        keyedBy: ReadStatusKeys.self)
      var readStatusOperatorContainer = readStatusItemContainer.nestedContainer(
        keyedBy: OperatorKeys.self, forKey: .readStatus)
      try readStatusOperatorContainer.encode("is", forKey: .operator)
      try readStatusOperatorContainer.encode(status.rawValue, forKey: .value)

    case .seriesStatus(let status):
      // Wrap in anyOf array
      var anyOfContainer = container.nestedContainer(keyedBy: AnyOfKeys.self)
      var anyOfArrayContainer = anyOfContainer.nestedUnkeyedContainer(forKey: .anyOf)
      var seriesStatusItemContainer = anyOfArrayContainer.nestedContainer(
        keyedBy: SeriesStatusKeys.self)
      var statusOperatorContainer = seriesStatusItemContainer.nestedContainer(
        keyedBy: OperatorKeys.self, forKey: .seriesStatus)
      try statusOperatorContainer.encode("is", forKey: .operator)
      try statusOperatorContainer.encode(status, forKey: .value)

    case .libraryIdAndSeriesStatus(let libraryId, let status):
      // For allOf, encode as two separate conditions
      var libraryContainer = container.nestedContainer(keyedBy: LibraryIdKeys.self)
      var libraryOperatorContainer = libraryContainer.nestedContainer(
        keyedBy: OperatorKeys.self, forKey: .libraryId)
      try libraryOperatorContainer.encode("is", forKey: .operator)
      try libraryOperatorContainer.encode(libraryId, forKey: .value)

      // Wrap in anyOf array
      var anyOfContainer = container.nestedContainer(keyedBy: AnyOfKeys.self)
      var anyOfArrayContainer = anyOfContainer.nestedUnkeyedContainer(forKey: .anyOf)
      var seriesStatusItemContainer = anyOfArrayContainer.nestedContainer(
        keyedBy: SeriesStatusKeys.self)
      var seriesStatusOperatorContainer = seriesStatusItemContainer.nestedContainer(
        keyedBy: OperatorKeys.self, forKey: .seriesStatus)
      try seriesStatusOperatorContainer.encode("is", forKey: .operator)
      try seriesStatusOperatorContainer.encode(status, forKey: .value)

    case .readStatusAndSeriesStatus(let readStatus, let seriesStatus):
      // For allOf, encode as two separate conditions
      // ReadStatus condition - wrap in anyOf
      var readStatusAnyOfContainer = container.nestedContainer(keyedBy: AnyOfKeys.self)
      var readStatusAnyOfArrayContainer = readStatusAnyOfContainer.nestedUnkeyedContainer(
        forKey: .anyOf)
      var readStatusItemContainer = readStatusAnyOfArrayContainer.nestedContainer(
        keyedBy: ReadStatusKeys.self)
      var readStatusOperatorContainer = readStatusItemContainer.nestedContainer(
        keyedBy: OperatorKeys.self, forKey: .readStatus)
      try readStatusOperatorContainer.encode("is", forKey: .operator)
      try readStatusOperatorContainer.encode(readStatus.rawValue, forKey: .value)

      // Wrap in anyOf array
      var anyOfContainer = container.nestedContainer(keyedBy: AnyOfKeys.self)
      var anyOfArrayContainer = anyOfContainer.nestedUnkeyedContainer(forKey: .anyOf)
      var seriesStatusItemContainer = anyOfArrayContainer.nestedContainer(
        keyedBy: SeriesStatusKeys.self)
      var seriesStatusOperatorContainer = seriesStatusItemContainer.nestedContainer(
        keyedBy: OperatorKeys.self, forKey: .seriesStatus)
      try seriesStatusOperatorContainer.encode("is", forKey: .operator)
      try seriesStatusOperatorContainer.encode(seriesStatus, forKey: .value)

    case .collectionId(let collectionId):
      var collectionContainer = container.nestedContainer(keyedBy: CollectionIdKeys.self)
      var collectionOperatorContainer = collectionContainer.nestedContainer(
        keyedBy: OperatorKeys.self, forKey: .collectionId)
      try collectionOperatorContainer.encode("is", forKey: .operator)
      try collectionOperatorContainer.encode(collectionId, forKey: .value)

    case .allOf(let nestedConditions):
      // Nested allOf - encode recursively
      for nestedCondition in nestedConditions {
        try encodeCondition(nestedCondition, into: &container)
      }
    }
  }
}

// Extension to convert ReadStatusFilter to ReadStatus
extension ReadStatusFilter {
  func toReadStatus() -> ReadStatus? {
    switch self {
    case .all:
      return nil
    case .read:
      return .read
    case .unread:
      return .unread
    case .inProgress:
      return .inProgress
    }
  }
}
