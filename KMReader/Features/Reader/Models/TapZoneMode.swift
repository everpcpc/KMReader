//
// TapZoneMode.swift
//
//

import SwiftUI

enum TapZoneMode: String, CaseIterable, Hashable, Sendable {
  case none = "none"
  case defaultLayout = "default"
  case edge = "edge"
  case kindle = "kindle"
  case lShape = "lShape"

  var displayName: String {
    switch self {
    case .none: return String(localized: "reader.tapZoneMode.none")
    case .defaultLayout: return String(localized: "reader.tapZoneMode.default")
    case .edge: return String(localized: "reader.tapZoneMode.edge")
    case .kindle: return String(localized: "reader.tapZoneMode.kindle")
    case .lShape: return String(localized: "reader.tapZoneMode.lShape")
    }
  }

  var isDisabled: Bool {
    self == .none
  }
}

enum TapZoneInversionMode: String, CaseIterable, Hashable, Sendable {
  case normal = "normal"
  case auto = "auto"
  case inverted = "inverted"

  var displayName: String {
    switch self {
    case .normal: return String(localized: "reader.tapZoneInversionMode.normal")
    case .auto: return String(localized: "reader.tapZoneInversionMode.auto")
    case .inverted: return String(localized: "reader.tapZoneInversionMode.inverted")
    }
  }

  func isInverted(for readingDirection: ReadingDirection) -> Bool {
    switch self {
    case .normal:
      return false
    case .auto:
      return readingDirection == .rtl
    case .inverted:
      return true
    }
  }
}
