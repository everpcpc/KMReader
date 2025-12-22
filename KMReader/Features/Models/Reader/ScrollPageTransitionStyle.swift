//
//  ScrollPageTransitionStyle.swift
//  KMReader
//

import Foundation

enum ScrollPageTransitionStyle: String, CaseIterable, Hashable {
  case `default` = "default"
  case fancy = "fancy"

  var displayName: String {
    switch self {
    case .default: return String(localized: "reader.scroll_transition.default")
    case .fancy: return String(localized: "reader.scroll_transition.fancy")
    }
  }

  var description: String {
    switch self {
    case .default: return String(localized: "reader.scroll_transition.default.description")
    case .fancy: return String(localized: "reader.scroll_transition.fancy.description")
    }
  }
}
