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
    case seriesId(String)
  }

  let condition: Condition

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

    case .seriesId(let seriesId):
      // Encode as: { "condition": { "seriesId": { "operator": "is", "value": "..." } } }
      var conditionContainer = container.nestedContainer(
        keyedBy: SeriesIdKeys.self, forKey: .condition)
      var seriesIdContainer = conditionContainer.nestedContainer(
        keyedBy: OperatorKeys.self, forKey: .seriesId)
      try seriesIdContainer.encode("is", forKey: .operator)
      try seriesIdContainer.encode(seriesId, forKey: .value)
    }
  }

  private enum CodingKeys: String, CodingKey {
    case condition
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

  private enum OperatorKeys: String, CodingKey {
    case `operator`
    case value
  }
}
