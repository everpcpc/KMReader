//
// SplitWidePageMode.swift
//
//

import Foundation

enum SplitWidePageMode: String, CaseIterable, Hashable {
  case none = "none"
  case auto = "auto"
  case ltr = "ltr"
  case rtl = "rtl"

  static func effectiveMode(
    preference: SplitWidePageMode,
    isUsingDualPage: Bool,
    transitionStyle: PageTransitionStyle
  ) -> SplitWidePageMode {
    guard isUsingDualPage else { return preference }

    switch transitionStyle {
    case .pageCurl:
      return .auto
    case .cover, .scroll:
      return .none
    }
  }

  static func supportsManualSelection(
    pageLayout: PageLayout,
    readingDirection: ReadingDirection,
    isUsingDualPage: Bool
  ) -> Bool {
    guard !isUsingDualPage else { return false }
    guard readingDirection != .webtoon, readingDirection != .vertical else { return false }
    return pageLayout == .single || pageLayout == .auto
  }

  var displayName: String {
    switch self {
    case .none:
      return String(localized: "reader.tapZoneMode.none")
    case .auto:
      return String(localized: "reader.tapZoneMode.auto")
    case .ltr:
      return String(localized: "reading_direction.ltr", defaultValue: "Left to Right")
    case .rtl:
      return String(localized: "reading_direction.rtl", defaultValue: "Right to Left")
    }
  }

  var icon: String {
    switch self {
    case .none:
      return "rectangle"
    case .auto:
      return "sparkles"
    case .ltr:
      return "rectangle.trailinghalf.inset.filled.arrow.trailing"
    case .rtl:
      return "rectangle.leadinghalf.inset.filled.arrow.leading"
    }
  }

  var isEnabled: Bool {
    self != .none
  }

  func effectiveReadingDirection(for readingDirection: ReadingDirection) -> ReadingDirection {
    switch self {
    case .none:
      return readingDirection
    case .auto:
      return readingDirection
    case .ltr:
      return .ltr
    case .rtl:
      return .rtl
    }
  }
}
