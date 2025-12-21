//
//  PageTransitionStyle.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftUI

enum PageTransitionStyle: String, CaseIterable, Hashable {
  case none = "none"
  case `default` = "default"
  case simple = "simple"
  case fancy = "fancy"

  var displayName: String {
    switch self {
    case .none: return String(localized: "reader.transition.none")
    case .default: return String(localized: "reader.transition.default")
    case .simple: return String(localized: "reader.transition.simple")
    case .fancy: return String(localized: "reader.transition.fancy")
    }
  }

  var description: String {
    switch self {
    case .none: return String(localized: "reader.transition.none.description")
    case .default: return String(localized: "reader.transition.default.description")
    case .simple: return String(localized: "reader.transition.simple.description")
    case .fancy: return String(localized: "reader.transition.fancy.description")
    }
  }

  var scrollAnimation: Animation? {
    switch self {
    case .none: return nil
    default: return PlatformHelper.readerAnimation
    }
  }
}
