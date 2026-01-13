//
//  TapZoneMode.swift
//  KMReader
//
//  Created by Antigravity
//

import SwiftUI

enum TapZoneMode: String, CaseIterable, Hashable {
  case none = "none"
  case auto = "auto"
  case ltr = "ltr"
  case rtl = "rtl"
  case vertical = "vertical"
  case webtoon = "webtoon"

  var displayName: String {
    switch self {
    case .none: return String(localized: "reader.tapZoneMode.none")
    case .auto: return String(localized: "reader.tapZoneMode.auto")
    case .ltr: return String(localized: "reading_direction.ltr")
    case .rtl: return String(localized: "reading_direction.rtl")
    case .vertical: return String(localized: "reading_direction.vertical")
    case .webtoon: return String(localized: "reading_direction.webtoon")
    }
  }

  var isDisabled: Bool {
    self == .none
  }

  /// Resolve the effective tap zone direction based on reading direction
  func effectiveDirection(for readingDirection: ReadingDirection) -> ReadingDirection? {
    switch self {
    case .none:
      return nil
    case .auto:
      return readingDirection
    case .ltr:
      return .ltr
    case .rtl:
      return .rtl
    case .vertical:
      return .vertical
    case .webtoon:
      return .webtoon
    }
  }
}
