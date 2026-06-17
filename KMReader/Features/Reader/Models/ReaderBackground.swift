//
// ReaderBackground.swift
//
//

import Foundation
import SwiftUI

enum ReaderBackground: String, CaseIterable, Hashable, Sendable {
  case black = "black"
  case white = "white"
  case gray = "gray"
  case sepia = "sepia"
  case system = "system"

  private static let sepiaBackground = Color(red: 244.0 / 255.0, green: 236.0 / 255.0, blue: 216.0 / 255.0)
  private static let sepiaForeground = Color(red: 92.0 / 255.0, green: 74.0 / 255.0, blue: 55.0 / 255.0)

  var displayName: String {
    switch self {
    case .black: return String(localized: "reader.background.black")
    case .white: return String(localized: "reader.background.white")
    case .gray: return String(localized: "reader.background.gray")
    case .sepia: return String(localized: "reader.background.sepia")
    case .system: return String(localized: "reader.background.system")
    }
  }

  var color: Color {
    switch self {
    case .black: return .black
    case .white: return .white
    case .gray: return .gray
    case .sepia: return Self.sepiaBackground
    case .system: return PlatformHelper.systemBackgroundColor
    }
  }

  var contentColor: Color {
    switch self {
    case .black, .gray:
      return .white
    case .white:
      return .black
    case .sepia:
      return Self.sepiaForeground
    case .system:
      return .primary
    }
  }

  var loadingCardFill: Color {
    switch self {
    case .black:
      return Color(.sRGB, white: 0.12, opacity: 1)
    case .white:
      return Color(.sRGB, white: 0.96, opacity: 1)
    case .gray:
      return Color(.sRGB, white: 0.42, opacity: 1)
    case .sepia:
      return Color(red: 250.0 / 255.0, green: 244.0 / 255.0, blue: 228.0 / 255.0)
    case .system:
      return PlatformHelper.secondarySystemBackgroundColor
    }
  }

  var loadingContentColor: Color {
    contentColor
  }

  var appliesImageMultiplyBlend: Bool {
    self == .sepia
  }
}
