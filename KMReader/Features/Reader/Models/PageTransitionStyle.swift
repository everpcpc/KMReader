//
// PageTransitionStyle.swift
//
//

import Foundation

enum PageTransitionStyle: String, CaseIterable, Hashable, Sendable {
  case scroll = "scroll"
  case cover = "cover"
  case pageCurl = "pageCurl"

  /// Platform-specific available cases
  static var availableCases: [PageTransitionStyle] {
    #if os(iOS)
      return [.scroll, .cover, .pageCurl]
    #else
      return [.scroll, .cover]
    #endif
  }

  static var epubAvailableCases: [PageTransitionStyle] {
    #if os(iOS)
      return [.scroll, .cover, .pageCurl]
    #else
      return [.scroll, .cover]
    #endif
  }

  var displayName: String {
    switch self {
    case .scroll: return String(localized: "reader.page_transition.scroll")
    case .cover: return String(localized: "reader.page_transition.cover")
    case .pageCurl: return String(localized: "reader.page_transition.page_curl")
    }
  }

  var description: String {
    switch self {
    case .scroll: return String(localized: "reader.page_transition.scroll.description")
    case .cover: return String(localized: "reader.page_transition.cover.description")
    case .pageCurl: return String(localized: "reader.page_transition.page_curl.description")
    }
  }
}
