//
//  GridDensity.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftUI

/// Preset options for grid card density selection in settings
enum GridDensity: Double, CaseIterable {
  case compact = 0.8  // Denser cards (smaller)
  case standard = 1.0  // Standard
  case cozy = 1.3  // More spacious cards (larger)

  var label: LocalizedStringKey {
    switch self {
    case .compact:
      return "settings.appearance.gridDensity.compact"
    case .standard:
      return "settings.appearance.gridDensity.standard"
    case .cozy:
      return "settings.appearance.gridDensity.cozy"
    }
  }

  static let icon: String = "slider.horizontal.3"

  /// Find the closest preset for a given density value
  static func closest(to value: Double) -> GridDensity {
    allCases.min(by: { abs($0.rawValue - value) < abs($1.rawValue - value) }) ?? .standard
  }
}
