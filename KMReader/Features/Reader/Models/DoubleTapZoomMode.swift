//
//  CustomFont.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation

enum DoubleTapZoomMode: String, CaseIterable, Identifiable {
  case disabled
  case fast
  case slow

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .disabled: return String(localized: "Disabled")
    case .fast: return String(localized: "Fast")
    case .slow: return String(localized: "Slow")
    }
  }

  var tapDebounceDelay: TimeInterval {
    switch self {
    case .disabled: return 0
    case .fast: return 0.18
    case .slow: return 0.3
    }
  }
}
