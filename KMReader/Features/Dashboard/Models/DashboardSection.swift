//
//  DashboardSection.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftData
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

  var isBookSection: Bool {
    switch self {
    case .keepReading, .onDeck, .recentlyReadBooks, .recentlyReleasedBooks, .recentlyAddedBooks:
      return true
    case .recentlyUpdatedSeries, .recentlyAddedSeries:
      return false
    }
  }

  func fetchBooks(libraryIds: [String], page: Int, size: Int) async throws -> Page<Book>? {
    switch self {
    case .keepReading:
      let condition = BookSearch.buildCondition(
        filters: BookSearchFilters(
          libraryIds: libraryIds,
          includeReadStatuses: [ReadStatus.inProgress]
        )
      )
      let search = BookSearch(condition: condition)
      return try await SyncService.shared.syncBooksList(
        search: search,
        page: page,
        size: size,
        sort: "readProgress.readDate,desc"
      )

    case .onDeck:
      return try await SyncService.shared.syncBooksOnDeck(
        libraryIds: libraryIds,
        page: page,
        size: size
      )

    case .recentlyReadBooks:
      return try await SyncService.shared.syncRecentlyReadBooks(
        libraryIds: libraryIds,
        page: page,
        size: size
      )

    case .recentlyReleasedBooks:
      return try await SyncService.shared.syncRecentlyReleasedBooks(
        libraryIds: libraryIds,
        page: page,
        size: size
      )

    case .recentlyAddedBooks:
      return try await SyncService.shared.syncRecentlyAddedBooks(
        libraryIds: libraryIds,
        page: page,
        size: size
      )

    default:
      return nil
    }
  }

  func fetchSeries(libraryIds: [String], page: Int, size: Int) async throws -> Page<Series>? {
    switch self {
    case .recentlyAddedSeries:
      return try await SyncService.shared.syncNewSeries(
        libraryIds: libraryIds,
        page: page,
        size: size
      )

    case .recentlyUpdatedSeries:
      return try await SyncService.shared.syncUpdatedSeries(
        libraryIds: libraryIds,
        page: page,
        size: size
      )

    default:
      return nil
    }
  }

  func fetchOfflineBookIds(
    context: ModelContext,
    libraryIds: [String],
    offset: Int,
    limit: Int
  ) -> [String] {
    switch self {
    case .keepReading:
      return KomgaBookStore.fetchKeepReadingBookIds(
        context: context,
        libraryIds: libraryIds,
        offset: offset,
        limit: limit
      )
    case .onDeck:
      return []
    case .recentlyReadBooks:
      return KomgaBookStore.fetchRecentlyReadBookIds(
        context: context,
        libraryIds: libraryIds,
        offset: offset,
        limit: limit
      )
    case .recentlyReleasedBooks:
      return KomgaBookStore.fetchRecentlyReleasedBookIds(
        context: context,
        libraryIds: libraryIds,
        offset: offset,
        limit: limit
      )
    case .recentlyAddedBooks:
      return KomgaBookStore.fetchRecentlyAddedBookIds(
        context: context,
        libraryIds: libraryIds,
        offset: offset,
        limit: limit
      )
    default:
      return []
    }
  }

  func fetchOfflineSeriesIds(
    context: ModelContext,
    libraryIds: [String],
    offset: Int,
    limit: Int
  ) -> [String] {
    switch self {
    case .recentlyAddedSeries:
      return KomgaSeriesStore.fetchNewlyAddedSeriesIds(
        context: context,
        libraryIds: libraryIds,
        offset: offset,
        limit: limit
      )
    case .recentlyUpdatedSeries:
      return KomgaSeriesStore.fetchRecentlyUpdatedSeriesIds(
        context: context,
        libraryIds: libraryIds,
        offset: offset,
        limit: limit
      )
    default:
      return []
    }
  }
}

// RawRepresentable wrapper for [DashboardSection] and libraryIds to use with @AppStorage
struct DashboardConfiguration: Equatable, RawRepresentable, Sendable {
  typealias RawValue = String

  var sections: [DashboardSection]
  var libraryIds: [String]

  nonisolated init(sections: [DashboardSection] = DashboardSection.allCases, libraryIds: [String] = []) {
    self.sections = sections
    self.libraryIds = libraryIds
  }

  nonisolated var rawValue: String {
    let dict: [String: Any] = [
      "sections": sections.map { $0.rawValue },
      "libraryIds": libraryIds,
    ]
    if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]),
      let json = String(data: data, encoding: .utf8)
    {
      return json
    }
    return "{}"
  }

  nonisolated init?(rawValue: String) {
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
