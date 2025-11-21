//
//  SeriesSearch.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation

// Simplified search structure that can encode to the correct JSON format for series list API
struct SeriesSearch: Encodable {
  let condition: [String: Any]?
  let fullTextSearch: String?

  init(condition: [String: Any]? = nil, fullTextSearch: String? = nil) {
    self.condition = condition
    self.fullTextSearch = fullTextSearch
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    if let condition = condition {
      // Use JSONSerialization to encode the condition dictionary
      let conditionJSON = try JSONSerialization.data(withJSONObject: condition)
      // Decode it back to a proper Codable structure
      let conditionDict = try JSONDecoder().decode([String: JSONAny].self, from: conditionJSON)
      try container.encodeIfPresent(conditionDict, forKey: .condition)
    }

    try container.encodeIfPresent(fullTextSearch, forKey: .fullTextSearch)
  }

  private enum CodingKeys: String, CodingKey {
    case condition
    case fullTextSearch
  }
}

// Helper type to encode/decode Any JSON value
private enum JSONAny: Codable {
  case string(String)
  case int(Int)
  case double(Double)
  case bool(Bool)
  case array([JSONAny])
  case dictionary([String: JSONAny])
  case null

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      self = .null
    } else if let bool = try? container.decode(Bool.self) {
      self = .bool(bool)
    } else if let int = try? container.decode(Int.self) {
      self = .int(int)
    } else if let double = try? container.decode(Double.self) {
      self = .double(double)
    } else if let string = try? container.decode(String.self) {
      self = .string(string)
    } else if let array = try? container.decode([JSONAny].self) {
      self = .array(array)
    } else if let dict = try? container.decode([String: JSONAny].self) {
      self = .dictionary(dict)
    } else {
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Cannot decode JSONAny"
      )
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .string(let value):
      try container.encode(value)
    case .int(let value):
      try container.encode(value)
    case .double(let value):
      try container.encode(value)
    case .bool(let value):
      try container.encode(value)
    case .array(let value):
      try container.encode(value)
    case .dictionary(let value):
      try container.encode(value)
    case .null:
      try container.encodeNil()
    }
  }
}

// Helper functions to build conditions
extension SeriesSearch {
  static func buildCondition(
    libraryId: String? = nil,
    readStatus: ReadStatus? = nil,
    seriesStatus: String? = nil,
    collectionId: String? = nil
  ) -> [String: Any]? {
    var conditions: [[String: Any]] = []

    if let libraryId = libraryId, !libraryId.isEmpty {
      conditions.append([
        "libraryId": ["operator": "is", "value": libraryId]
      ])
    }

    if let readStatus = readStatus {
      // For series, readStatus needs to be wrapped in anyOf
      conditions.append([
        "anyOf": [
          [
            "readStatus": ["operator": "is", "value": readStatus.rawValue]
          ]
        ]
      ])
    }

    if let seriesStatus = seriesStatus {
      // Series status also needs to be wrapped in anyOf
      conditions.append([
        "anyOf": [
          [
            "seriesStatus": ["operator": "is", "value": seriesStatus]
          ]
        ]
      ])
    }

    if let collectionId = collectionId {
      conditions.append([
        "collectionId": ["operator": "is", "value": collectionId]
      ])
    }

    if conditions.isEmpty {
      return nil
    } else if conditions.count == 1 {
      return conditions[0]
    } else {
      return ["allOf": conditions]
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
