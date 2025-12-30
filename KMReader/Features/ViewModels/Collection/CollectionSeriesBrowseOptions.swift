//
//  CollectionSeriesBrowseOptions.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftUI

struct CollectionSeriesBrowseOptions: Equatable, RawRepresentable {
  typealias RawValue = String

  var includeReadStatuses: Set<ReadStatus> = []
  var excludeReadStatuses: Set<ReadStatus> = []
  var includeSeriesStatuses: Set<SeriesStatus> = []
  var excludeSeriesStatuses: Set<SeriesStatus> = []
  var seriesStatusLogic: StatusFilterLogic = .all
  var completeFilter: TriStateFilter<BoolTriStateFlag> = TriStateFilter()
  var oneshotFilter: TriStateFilter<BoolTriStateFlag> = TriStateFilter()
  var deletedFilter: TriStateFilter<BoolTriStateFlag> = TriStateFilter()

  var rawValue: String {
    let dict: [String: String] = [
      "includeReadStatuses": includeReadStatuses.map { $0.rawValue }.sorted().joined(
        separator: ","
      ),
      "excludeReadStatuses": excludeReadStatuses.map { $0.rawValue }.sorted().joined(
        separator: ","
      ),
      "includeSeriesStatuses": includeSeriesStatuses.map { $0.apiValue }.sorted().joined(
        separator: ","
      ),
      "excludeSeriesStatuses": excludeSeriesStatuses.map { $0.apiValue }.sorted().joined(
        separator: ","
      ),
      "seriesStatusLogic": seriesStatusLogic.rawValue,
      "completeFilter": completeFilter.storageValue,
      "oneshotFilter": oneshotFilter.storageValue,
      "deletedFilter": deletedFilter.storageValue,
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
    let includeReadRaw = dict["includeReadStatuses"] ?? ""
    let excludeReadRaw = dict["excludeReadStatuses"] ?? ""
    self.includeReadStatuses = Set(
      includeReadRaw.split(separator: ",").compactMap { ReadStatus(rawValue: String($0)) })
    self.excludeReadStatuses = Set(
      excludeReadRaw.split(separator: ",").compactMap { ReadStatus(rawValue: String($0)) })

    if includeReadStatuses.isEmpty && excludeReadStatuses.isEmpty,
      let legacyRead = dict["readStatusFilter"]
    {
      let tri = TriStateFilter<ReadStatus>.decode(legacyRead)
      if let value = tri.value {
        if tri.state == .exclude {
          excludeReadStatuses.insert(value)
        } else if tri.state == .include {
          includeReadStatuses.insert(value)
        }
      }
    }
    let includeRaw = dict["includeSeriesStatuses"] ?? ""
    let excludeRaw = dict["excludeSeriesStatuses"] ?? ""
    self.includeSeriesStatuses = Set(
      includeRaw.split(separator: ",").compactMap { SeriesStatus.fromAPIValue(String($0)) })
    self.excludeSeriesStatuses = Set(
      excludeRaw.split(separator: ",").compactMap { SeriesStatus.fromAPIValue(String($0)) })

    if includeSeriesStatuses.isEmpty && excludeSeriesStatuses.isEmpty,
      let legacy = dict["seriesStatusFilter"]
    {
      let tri = TriStateFilter<SeriesStatus>.decode(legacy)
      if let value = tri.value {
        if tri.state == .exclude {
          excludeSeriesStatuses.insert(value)
        } else if tri.state == .include {
          includeSeriesStatuses.insert(value)
        }
      }
    }

    let logicRaw = dict["seriesStatusLogic"] ?? ""
    self.seriesStatusLogic =
      StatusFilterLogic(rawValue: logicRaw)
      ?? (logicRaw == "AND" ? .all : logicRaw == "OR" ? .any : .all)
    self.completeFilter = TriStateFilter.decode(dict["completeFilter"])
    self.oneshotFilter = TriStateFilter.decode(dict["oneshotFilter"])
    self.deletedFilter = TriStateFilter.decode(dict["deletedFilter"])
  }

  init() {}
}
