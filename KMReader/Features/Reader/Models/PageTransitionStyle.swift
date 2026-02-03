//
//  PageTransitionStyle.swift
//  KMReader
//

import Foundation

enum PageTransitionStyle: String, CaseIterable, Hashable {
  case scroll = "scroll"
  case pageCurl = "pageCurl"

  /// Platform-specific available cases
  static var availableCases: [PageTransitionStyle] {
    #if os(iOS)
      return allCases
    #else
      return [.scroll]
    #endif
  }

  var displayName: String {
    switch self {
    case .scroll: return String(localized: "reader.page_transition.scroll")
    case .pageCurl: return String(localized: "reader.page_transition.page_curl")
    }
  }

  var description: String {
    switch self {
    case .scroll: return String(localized: "reader.page_transition.scroll.description")
    case .pageCurl: return String(localized: "reader.page_transition.page_curl.description")
    }
  }
}
