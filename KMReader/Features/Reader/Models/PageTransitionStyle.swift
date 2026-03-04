//
// PageTransitionStyle.swift
//
//

import Foundation

enum PageTransitionStyle: String, CaseIterable, Hashable {
  case scroll = "scroll"
  case pageCurl = "pageCurl"
  case cover = "cover"

  /// Platform-specific available cases
  static var availableCases: [PageTransitionStyle] {
    #if os(iOS)
      return allCases
    #else
      return [.scroll, .cover]
    #endif
  }

  static var epubAvailableCases: [PageTransitionStyle] {
    #if os(iOS)
      return [.scroll, .pageCurl]
    #else
      return [.scroll]
    #endif
  }

  var displayName: String {
    switch self {
    case .scroll: return String(localized: "reader.page_transition.scroll")
    case .pageCurl: return String(localized: "reader.page_transition.page_curl")
    case .cover: return String(localized: "reader.page_transition.cover")
    }
  }

  var description: String {
    switch self {
    case .scroll: return String(localized: "reader.page_transition.scroll.description")
    case .pageCurl: return String(localized: "reader.page_transition.page_curl.description")
    case .cover: return String(localized: "reader.page_transition.cover.description")
    }
  }
}
