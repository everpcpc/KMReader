//
//  DashboardSectionCache.swift
//  KMReader
//

import Foundation

/// Caches the first page of item IDs for each dashboard section
struct DashboardSectionCache: Equatable, RawRepresentable {
  typealias RawValue = String

  var sectionIds: [DashboardSection: [String]]

  init(sectionIds: [DashboardSection: [String]] = [:]) {
    self.sectionIds = sectionIds
  }

  func ids(for section: DashboardSection) -> [String] {
    sectionIds[section] ?? []
  }

  mutating func update(section: DashboardSection, ids: [String]) {
    sectionIds[section] = ids
  }

  var rawValue: String {
    // Convert to a simple dictionary with section rawValue as key
    let dict = sectionIds.reduce(into: [String: [String]]()) { result, pair in
      result[pair.key.rawValue] = pair.value
    }
    if let data = try? JSONSerialization.data(withJSONObject: dict),
      let json = String(data: data, encoding: .utf8)
    {
      return json
    }
    return "{}"
  }

  init?(rawValue: String) {
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
