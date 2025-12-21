//
//  SeriesOfflinePolicy.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation

/// Policy for automatic offline book management within a series.
enum SeriesOfflinePolicy: String, Codable, CaseIterable, Sendable {
  /// Manual mode: Books only downloaded/deleted via manual user actions.
  case manual
  /// Automatically download all unread books in the series.
  case unreadOnly
  /// Automatically download unread books and delete books once they are read.
  case unreadOnlyAndCleanupRead
  /// Automatically download all books in the series regardless of read status.
  case all

  var label: String {
    switch self {
    case .manual:
      return String(localized: "policy.manual")
    case .unreadOnly:
      return String(localized: "policy.unread_only")
    case .unreadOnlyAndCleanupRead:
      return String(localized: "policy.unread_only_cleanup")
    case .all:
      return String(localized: "policy.all")
    }
  }

  var icon: String {
    switch self {
    case .manual:
      return "hand.tap"
    case .unreadOnly:
      return "book.circle"
    case .unreadOnlyAndCleanupRead:
      return "leaf.arrow.triangle.circlepath"
    case .all:
      return "infinity"
    }
  }
}
