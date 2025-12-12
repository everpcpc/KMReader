//
//  PageTransitionStyle.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftUI

enum PageTransitionStyle: String, CaseIterable, Hashable {
  case instant = "instant"
  case none = "none"
  case simple = "simple"
  case fancy = "fancy"

  var displayName: String {
    switch self {
    case .instant: return String(localized: "reader.transition.instant")
    case .none: return String(localized: "reader.transition.none")
    case .simple: return String(localized: "reader.transition.simple")
    case .fancy: return String(localized: "reader.transition.fancy")
    }
  }

  var description: String {
    switch self {
    case .instant: return String(localized: "reader.transition.instant.description")
    case .none: return String(localized: "reader.transition.none.description")
    case .simple: return String(localized: "reader.transition.simple.description")
    case .fancy: return String(localized: "reader.transition.fancy.description")
    }
  }

  var scrollAnimation: Animation? {
    switch self {
    case .instant: return nil
    default: return PlatformHelper.readerAnimation
    }
  }
}
