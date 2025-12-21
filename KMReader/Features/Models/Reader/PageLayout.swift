//
//  PageLayout.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation

enum PageLayout: String, CaseIterable, Hashable {
  case single = "single"
  case auto = "auto"
  case dual = "dual-forced"

  var displayName: String {
    switch self {
    case .single:
      return String(localized: "reader.pageLayout.single")
    case .auto:
      return String(localized: "reader.pageLayout.auto")
    case .dual:
      return String(localized: "reader.pageLayout.dual")
    }
  }

  var icon: String {
    switch self {
    case .single:
      return "rectangle.portrait"
    case .auto:
      return "sparkles"
    case .dual:
      return "rectangle.split.2x1"
    }
  }

  var supportsDualPageOptions: Bool {
    switch self {
    case .single:
      return false
    case .auto, .dual:
      return true
    }
  }
}
