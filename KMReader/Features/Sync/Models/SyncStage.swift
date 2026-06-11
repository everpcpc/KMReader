//
// SyncStage.swift
//
//

import Foundation

nonisolated enum SyncStage: String, CaseIterable, Sendable {
  case libraries
  case collections
  case seriesIncremental
  case seriesReconcile
  case readLists
  case booksIncremental
  case booksReconcile

  static func visibleStages(includeReconcile: Bool) -> [SyncStage] {
    if includeReconcile {
      [
        .libraries,
        .collections,
        .seriesIncremental,
        .seriesReconcile,
        .readLists,
        .booksIncremental,
        .booksReconcile,
      ]
    } else {
      [
        .libraries,
        .collections,
        .seriesIncremental,
        .readLists,
        .booksIncremental,
      ]
    }
  }

  static var initialProgress: [SyncStage: Double] {
    Dictionary(uniqueKeysWithValues: allCases.map { ($0, 0.0) })
  }

  func localizedName(includeReconcile: Bool) -> String {
    switch self {
    case .libraries:
      return String(localized: "initialization.phase.libraries")
    case .collections:
      return String(localized: "initialization.phase.collections")
    case .seriesIncremental:
      let base = String(localized: "initialization.phase.series")
      return includeReconcile ? "\(base) (1/2)" : base
    case .seriesReconcile:
      let base = String(localized: "initialization.phase.series")
      return "\(base) (2/2)"
    case .readLists:
      return String(localized: "initialization.phase.readlists")
    case .booksIncremental:
      let base = String(localized: "initialization.phase.books")
      return includeReconcile ? "\(base) (1/2)" : base
    case .booksReconcile:
      let base = String(localized: "initialization.phase.books")
      return "\(base) (2/2)"
    }
  }
}
