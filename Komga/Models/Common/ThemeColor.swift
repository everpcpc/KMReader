//
//  ThemeColor.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

enum ThemeColorOption: String, CaseIterable {
  case orange = "orange"
  case red = "red"
  case yellow = "yellow"
  case green = "green"
  case mint = "mint"
  case teal = "teal"
  case cyan = "cyan"
  case blue = "blue"
  case indigo = "indigo"
  case purple = "purple"
  case pink = "pink"
  case brown = "brown"

  var color: Color {
    switch self {
    case .orange: return .orange
    case .red: return .red
    case .yellow: return .yellow
    case .green: return .green
    case .mint: return .mint
    case .teal: return .teal
    case .cyan: return .cyan
    case .blue: return .blue
    case .indigo: return .indigo
    case .purple: return .purple
    case .pink: return .pink
    case .brown: return .brown
    }
  }

  var displayName: String {
    switch self {
    case .orange: return "Orange"
    case .red: return "Red"
    case .yellow: return "Yellow"
    case .green: return "Green"
    case .mint: return "Mint"
    case .teal: return "Teal"
    case .cyan: return "Cyan"
    case .blue: return "Blue"
    case .indigo: return "Indigo"
    case .purple: return "Purple"
    case .pink: return "Pink"
    case .brown: return "Brown"
    }
  }
}
