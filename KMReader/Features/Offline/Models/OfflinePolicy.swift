//
// OfflinePolicy.swift
//
//

import Foundation

/// Policy for automatic offline book management within a series or read list.
nonisolated enum OfflinePolicy: Codable, CaseIterable, Sendable {
  /// Manual mode: Books only downloaded/deleted via manual user actions.
  case manual
  /// Automatically download all unread books in the source.
  case unreadOnly
  /// Automatically download all books in the source regardless of read status.
  case all

  static var allCases: [OfflinePolicy] {
    [.manual, .unreadOnly, .all]
  }

  init(storageValue: String) {
    switch storageValue {
    case "unreadOnly", "unreadOnlyAndCleanupRead":
      self = .unreadOnly
    case "all":
      self = .all
    default:
      self = .manual
    }
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    self.init(storageValue: try container.decode(String.self))
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(storageValue)
  }

  var storageValue: String {
    switch self {
    case .manual:
      return "manual"
    case .unreadOnly:
      return "unreadOnly"
    case .all:
      return "all"
    }
  }

  var label: String {
    switch self {
    case .manual:
      return String(localized: "policy.manual")
    case .unreadOnly:
      return String(localized: "policy.unread_only")
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
    case .all:
      return "infinity"
    }
  }

  var supportsLimit: Bool {
    switch self {
    case .unreadOnly:
      return true
    case .manual, .all:
      return false
    }
  }

  func title(limit: Int) -> String {
    if supportsLimit {
      return "\(label) (\(Self.limitTitle(limit)))"
    }
    return label
  }

  static func limitTitle(_ value: Int) -> String {
    if value <= 0 {
      return "∞"
    }
    return "\(value)"
  }
}
