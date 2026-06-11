//
// SyncPhase.swift
//
//

import Foundation

nonisolated enum SyncPhase: String, CaseIterable, Sendable {
  case libraries
  case collections
  case series
  case readLists
  case books

  var localizedName: String {
    switch self {
    case .libraries:
      String(localized: "initialization.phase.libraries")
    case .collections:
      String(localized: "initialization.phase.collections")
    case .series:
      String(localized: "initialization.phase.series")
    case .readLists:
      String(localized: "initialization.phase.readlists")
    case .books:
      String(localized: "initialization.phase.books")
    }
  }

  var weight: Double {
    switch self {
    case .libraries: 0.05
    case .collections: 0.1
    case .series: 0.25
    case .readLists: 0.1
    case .books: 0.5
    }
  }

  static var totalWeight: Double {
    allCases.reduce(0) { $0 + $1.weight }
  }

  static var initialProgress: [SyncPhase: Double] {
    Dictionary(uniqueKeysWithValues: allCases.map { ($0, 0.0) })
  }

  var progressOffset: Double {
    var offset = 0.0
    for phase in SyncPhase.allCases {
      if phase == self { break }
      offset += phase.weight
    }
    return offset / SyncPhase.totalWeight
  }
}
