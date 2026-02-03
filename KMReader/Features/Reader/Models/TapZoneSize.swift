//
//  TapZoneSize.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

enum TapZoneSize: String, CaseIterable, Hashable {
  case large = "large"
  case medium = "medium"
  case small = "small"

  var displayName: String {
    switch self {
    case .large: return String(localized: "reader.tapZoneSize.large")
    case .medium: return String(localized: "reader.tapZoneSize.medium")
    case .small: return String(localized: "reader.tapZoneSize.small")
    }
  }

  var value: CGFloat {
    switch self {
    case .large: return 0.35
    case .medium: return 0.25
    case .small: return 0.15
    }
  }
}
