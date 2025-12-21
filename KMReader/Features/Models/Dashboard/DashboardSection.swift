//
//  DashboardSection.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftUI

enum DashboardSection: String, CaseIterable, Identifiable, Codable {
  case keepReading = "keepReading"
  case onDeck = "onDeck"
  case recentlyReleasedBooks = "recentlyReleasedBooks"
  case recentlyAddedBooks = "recentlyAddedBooks"
  case recentlyAddedSeries = "recentlyAddedSeries"
  case recentlyUpdatedSeries = "recentlyUpdatedSeries"
  case recentlyReadBooks = "recentlyReadBooks"

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .keepReading:
      return String(localized: "dashboard.keepReading")
    case .onDeck:
      return String(localized: "dashboard.onDeck")
    case .recentlyReleasedBooks:
      return String(localized: "dashboard.recentlyReleasedBooks")
    case .recentlyAddedBooks:
      return String(localized: "dashboard.recentlyAddedBooks")
    case .recentlyUpdatedSeries:
      return String(localized: "dashboard.recentlyUpdatedSeries")
    case .recentlyAddedSeries:
      return String(localized: "dashboard.recentlyAddedSeries")
    case .recentlyReadBooks:
      return String(localized: "dashboard.recentlyReadBooks")
    }
  }

  var icon: String {
    switch self {
    case .keepReading:
      return "book.fill"
    case .onDeck:
      return "bookmark.fill"
    case .recentlyReleasedBooks:
      return "calendar.badge.clock"
    case .recentlyAddedBooks:
      return "sparkles"
    case .recentlyUpdatedSeries:
      return "arrow.triangle.2.circlepath.circle.fill"
    case .recentlyAddedSeries:
      return "square.stack.3d.up.fill"
    case .recentlyReadBooks:
      return "checkmark.circle.fill"
    }
  }
}

// RawRepresentable wrapper for [DashboardSection] and libraryIds to use with @AppStorage
struct DashboardConfiguration: Equatable, RawRepresentable {
  typealias RawValue = String

  var sections: [DashboardSection]
  var libraryIds: [String]

  init(sections: [DashboardSection] = DashboardSection.allCases, libraryIds: [String] = []) {
    self.sections = sections
    self.libraryIds = libraryIds
  }

  var rawValue: String {
    let dict: [String: Any] = [
      "sections": sections.map { $0.rawValue },
      "libraryIds": libraryIds,
    ]
    if let data = try? JSONSerialization.data(withJSONObject: dict),
      let json = String(data: data, encoding: .utf8)
    {
      return json
    }
    return "{}"
  }

  init?(rawValue: String) {
    guard !rawValue.isEmpty else {
      self.sections = DashboardSection.allCases
      self.libraryIds = []
      return
    }
    guard let data = rawValue.data(using: .utf8),
      let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
      self.sections = DashboardSection.allCases
      self.libraryIds = []
      return
    }

    // Parse sections
    if let sectionsArray = dict["sections"] as? [String] {
      self.sections = sectionsArray.compactMap { DashboardSection(rawValue: $0) }
      if self.sections.isEmpty {
        self.sections = DashboardSection.allCases
      }
    } else {
      self.sections = DashboardSection.allCases
    }

    // Parse libraryIds
    if let libraryIdsArray = dict["libraryIds"] as? [String] {
      self.libraryIds = libraryIdsArray
    } else {
      self.libraryIds = []
    }
  }
}
