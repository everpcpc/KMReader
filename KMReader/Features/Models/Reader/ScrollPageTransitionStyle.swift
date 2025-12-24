//
//  ScrollPageTransitionStyle.swift
//  KMReader
//

import Foundation

enum ScrollPageTransitionStyle: String, CaseIterable, Hashable {
  case `default` = "default"
  case fade = "fade"
  case scale = "scale"
  case rotation3D = "rotation3D"
  case cube = "cube"

  var displayName: String {
    switch self {
    case .default: return String(localized: "reader.scroll_transition.default")
    case .fade: return String(localized: "reader.scroll_transition.fade")
    case .scale: return String(localized: "reader.scroll_transition.scale")
    case .rotation3D: return String(localized: "reader.scroll_transition.rotation3D")
    case .cube: return String(localized: "reader.scroll_transition.cube")
    }
  }

  var description: String {
    switch self {
    case .default: return String(localized: "reader.scroll_transition.default.description")
    case .fade: return String(localized: "reader.scroll_transition.fade.description")
    case .scale: return String(localized: "reader.scroll_transition.scale.description")
    case .rotation3D: return String(localized: "reader.scroll_transition.rotation3D.description")
    case .cube: return String(localized: "reader.scroll_transition.cube.description")
    }
  }
}
