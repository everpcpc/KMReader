//
//  ReadingDirection.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftUI

enum ReadingDirection: CaseIterable, Hashable {
  case ltr
  case rtl
  case vertical
  case webtoon

  /// Get available reading directions for current platform
  static var availableCases: [ReadingDirection] {
    #if canImport(UIKit)
      return allCases
    #else
      // Webtoon requires UIKit
      return [.ltr, .rtl, .vertical]
    #endif
  }

  /// Check if this reading direction is supported on current platform
  var isSupported: Bool {
    #if canImport(UIKit)
      return true
    #else
      // Webtoon requires UIKit
      return self != .webtoon
    #endif
  }

  static func fromString(_ direction: String?) -> ReadingDirection {
    guard let direction = direction else {
      return .ltr
    }
    switch direction.uppercased() {
    case "LEFT_TO_RIGHT":
      return .ltr
    case "RIGHT_TO_LEFT":
      return .rtl
    case "VERTICAL":
      return .vertical
    case "WEBTOON":
      return .webtoon
    default:
      return .ltr
    }
  }

  var displayName: String {
    switch self {
    case .ltr:
      return "LTR"
    case .rtl:
      return "RTL"
    case .vertical:
      return "Vertical"
    case .webtoon:
      return "Webtoon"
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

  var apiValue: String {
    switch self {
    case .ltr:
      return "LEFT_TO_RIGHT"
    case .rtl:
      return "RIGHT_TO_LEFT"
    case .vertical:
      return "VERTICAL"
    case .webtoon:
      return "WEBTOON"
    }
  }
}
