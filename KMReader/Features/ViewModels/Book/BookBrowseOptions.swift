//
//  BookBrowseOptions.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftUI

nonisolated struct BookBrowseOptions: Equatable, RawRepresentable {
  typealias RawValue = String

  var includeReadStatuses: Set<ReadStatus> = []
  var excludeReadStatuses: Set<ReadStatus> = []
  var oneshotFilter: TriStateFilter<BoolTriStateFlag> = TriStateFilter()
  var deletedFilter: TriStateFilter<BoolTriStateFlag> = TriStateFilter()
  var metadataFilter: MetadataFilterConfig = MetadataFilterConfig()
  var sortField: BookSortField = .series
  var sortDirection: SortDirection = .ascending

  var sortString: String {
    return "\(sortField.rawValue),\(sortDirection.rawValue)"
  }

  var rawValue: String {
    let dict: [String: String] = [
      "includeReadStatuses": includeReadStatuses.map { $0.rawValue }.sorted().joined(
        separator: ","
      ),
      "excludeReadStatuses": excludeReadStatuses.map { $0.rawValue }.sorted().joined(
        separator: ","
      ),
      "oneshotFilter": oneshotFilter.storageValue,
      "deletedFilter": deletedFilter.storageValue,
      "metadataFilter": metadataFilter.rawValue,
      "sortField": sortField.rawValue,
      "sortDirection": sortDirection.rawValue,
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
      return nil
    }
    guard let data = rawValue.data(using: .utf8),
      let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String]
    else {
      return nil
    }
    let includeRaw = dict["includeReadStatuses"] ?? ""
    let excludeRaw = dict["excludeReadStatuses"] ?? ""
    self.includeReadStatuses = Set(
      includeRaw.split(separator: ",").compactMap { ReadStatus(rawValue: String($0)) })
    self.excludeReadStatuses = Set(
      excludeRaw.split(separator: ",").compactMap { ReadStatus(rawValue: String($0)) })

    self.oneshotFilter = TriStateFilter.decode(dict["oneshotFilter"])
    self.deletedFilter = TriStateFilter.decode(dict["deletedFilter"])
    self.metadataFilter =
      MetadataFilterConfig(rawValue: dict["metadataFilter"] ?? "") ?? MetadataFilterConfig()

    // backward compatibility with legacy tri-state
    if includeReadStatuses.isEmpty && excludeReadStatuses.isEmpty,
      let legacy = dict["readStatusFilter"]
    {
      let tri = TriStateFilter<ReadStatus>.decode(legacy)
      if let value = tri.value {
        if tri.state == .exclude {
          excludeReadStatuses.insert(value)
        } else if tri.state == .include {
          includeReadStatuses.insert(value)
        }
      }
    }

    self.sortField = BookSortField(rawValue: dict["sortField"] ?? "") ?? .series
    self.sortDirection = SortDirection(rawValue: dict["sortDirection"] ?? "") ?? .ascending
  }

  init() {}
}
