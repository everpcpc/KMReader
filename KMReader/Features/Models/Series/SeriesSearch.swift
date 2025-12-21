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

struct SeriesSearchFilters {
  var libraryIds: [String]? = nil
  var includeReadStatuses: [ReadStatus] = []
  var excludeReadStatuses: [ReadStatus] = []
  var includeSeriesStatuses: [String] = []
  var excludeSeriesStatuses: [String] = []
  var seriesStatusLogic: StatusFilterLogic = .all
  /// oneshot = true / false / nil
  var oneshot: Bool? = nil
  /// deleted = true / false / nil
  var deleted: Bool? = nil
  /// complete = true / false / nil
  var complete: Bool? = nil
  var collectionId: String? = nil
}

// Helper functions to build conditions
extension SeriesSearch {
  static func buildCondition(filters: SeriesSearchFilters) -> [String: Any]? {
    var conditions: [[String: Any]] = []

    // Support multiple libraryIds using anyOf
    if let libraryIds = filters.libraryIds, !libraryIds.isEmpty {
      if libraryIds.count == 1 {
        // Single libraryId - use simple condition
        conditions.append([
          "libraryId": ["operator": "is", "value": libraryIds[0]]
        ])
      } else {
        // Multiple libraryIds - use anyOf to combine
        let libraryConditions = libraryIds.map { id in
          ["libraryId": ["operator": "is", "value": id]]
        }
        conditions.append(["anyOf": libraryConditions])
      }
    }

    if !filters.includeReadStatuses.isEmpty {
      let statusConditions = filters.includeReadStatuses.map {
        ["readStatus": ["operator": "is", "value": $0.rawValue]]
      }
      conditions.append(["anyOf": statusConditions])
    }

    if !filters.excludeReadStatuses.isEmpty {
      let statusConditions = filters.excludeReadStatuses.map {
        ["readStatus": ["operator": "isnot", "value": $0.rawValue]]
      }
      conditions.append(["allOf": statusConditions])
    }

    if !filters.includeSeriesStatuses.isEmpty {
      let statusConditions = filters.includeSeriesStatuses.map { status in
        ["seriesStatus": ["operator": "is", "value": status]]
      }
      let wrapperKey = filters.seriesStatusLogic == .all ? "allOf" : "anyOf"
      conditions.append([wrapperKey: statusConditions])
    }

    if !filters.excludeSeriesStatuses.isEmpty {
      let statusConditions = filters.excludeSeriesStatuses.map { status in
        ["seriesStatus": ["operator": "isnot", "value": status]]
      }
      let wrapperKey = filters.seriesStatusLogic == .all ? "allOf" : "anyOf"
      conditions.append([wrapperKey: statusConditions])
    }

    if let oneshot = filters.oneshot {
      conditions.append([
        "oneshot": [
          "operator": oneshot ? "istrue" : "isfalse"
        ]
      ])
    }

    if let complete = filters.complete {
      conditions.append([
        "complete": [
          "operator": complete ? "istrue" : "isfalse"
        ]
      ])
    }

    if let deleted = filters.deleted {
      conditions.append([
        "deleted": [
          "operator": deleted ? "istrue" : "isfalse"
        ]
      ])
    }

    if let collectionId = filters.collectionId {
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
