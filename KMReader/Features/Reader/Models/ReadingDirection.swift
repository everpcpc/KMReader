//
//  ReadingDirection.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftUI

enum ReadingDirection: String, CaseIterable, Hashable, Codable {
  case ltr = "LEFT_TO_RIGHT"
  case rtl = "RIGHT_TO_LEFT"
  case vertical = "VERTICAL"
  case webtoon = "WEBTOON"

  /// Get available reading directions for current platform
  static var availableCases: [ReadingDirection] {
    #if os(iOS) || os(macOS)
      return allCases
    #else
      // Webtoon requires iOS/iPadOS/macOS (not watchOS or tvOS)
      return [.ltr, .rtl, .vertical]
    #endif
  }

  /// Check if this reading direction is supported on current platform
  var isSupported: Bool {
    #if os(iOS) || os(macOS)
      return true
    #else
      // Webtoon requires iOS/iPadOS/macOS (not watchOS or tvOS)
      return self != .webtoon
    #endif
  }

  static func fromString(_ direction: String?) -> ReadingDirection {
    guard let direction = direction else {
      return .ltr
    }
    let rawValue = direction.uppercased()
    return ReadingDirection(rawValue: rawValue) ?? .ltr
  }

  var displayName: String {
    switch self {
    case .ltr:
      return String(localized: "reading_direction.ltr", defaultValue: "Left to Right")
    case .rtl:
      return String(localized: "reading_direction.rtl", defaultValue: "Right to Left")
    case .vertical:
      return String(localized: "reading_direction.vertical", defaultValue: "Vertical")
    case .webtoon:
      return String(localized: "reading_direction.webtoon", defaultValue: "Webtoon")
    }
  }

  var icon: String {
    switch self {
    case .ltr:
      return "rectangle.trailinghalf.inset.filled.arrow.trailing"
    case .rtl:
      return "rectangle.leadinghalf.inset.filled.arrow.leading"
    case .vertical:
      return "arrow.up.arrow.down.square"
    case .webtoon:
      return "arrow.up.and.down.square"
    }
  }

  /// Check if the given translation represents a forward swipe (toward next page/book)
  func isForwardSwipe(_ translation: CGFloat) -> Bool {
    self == .rtl ? translation > 0 : translation < 0
  }
}
