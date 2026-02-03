//
//  DashboardSectionCache.swift
//  KMReader
//

import Foundation

/// Caches the first page of item IDs for each dashboard section
struct DashboardSectionCache: Equatable, RawRepresentable, Sendable {
  typealias RawValue = String

  var sectionIds: [DashboardSection: [String]]

  nonisolated init(sectionIds: [DashboardSection: [String]] = [:]) {
    self.sectionIds = sectionIds
  }

  func ids(for section: DashboardSection) -> [String] {
    sectionIds[section] ?? []
  }

  mutating func updateIfChanged(section: DashboardSection, ids: [String]) -> Bool {
    if sectionIds[section] == ids {
      return false
    }
    sectionIds[section] = ids
    return true
  }

  nonisolated var rawValue: String {
    // Convert to a simple dictionary with section rawValue as key
    let dict = sectionIds.reduce(into: [String: [String]]()) { result, pair in
      result[pair.key.rawValue] = pair.value
    }
    if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]),
      let json = String(data: data, encoding: .utf8)
    {
      return json
    }
    return "{}"
  }

  nonisolated init?(rawValue: String) {
    guard !rawValue.isEmpty,
      let data = rawValue.data(using: .utf8),
      let dict = try? JSONSerialization.jsonObject(with: data) as? [String: [String]]
    else {
      self.sectionIds = [:]
      return
    }

    self.sectionIds = dict.reduce(into: [DashboardSection: [String]]()) { result, pair in
      if let section = DashboardSection(rawValue: pair.key) {
        result[section] = pair.value
      }
    }
  }
}
