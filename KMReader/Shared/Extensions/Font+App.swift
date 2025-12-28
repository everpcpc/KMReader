//
//  Font+App.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftUI

extension Font {
  /// Returns a serif font appropriate for the current locale.
  /// - Parameter size: The font size.
  /// - Returns: A Font instance.
  static func appSerifDesign(size: CGFloat, weight: Font.Weight = .regular) -> Font {
    let language = Locale.current.language.languageCode?.identifier ?? "en"
    let isBold = weight == .bold || weight == .heavy || weight == .black || weight == .semibold

    switch language {
    case "zh":
      // Check for Traditional vs Simplified
      if let script = Locale.current.language.script?.identifier {
        if script == "Hant" {
          return .custom(isBold ? "STSongti-TC-Bold" : "STSongti-TC-Regular", size: size)
        }
      }
      // Default to Simplified for "zh" if script is missing or is Hans
      return .custom(isBold ? "STSongti-SC-Bold" : "STSongti-SC-Regular", size: size)
    case "ja":
      return .custom(isBold ? "HiraMinProN-W6" : "HiraMinProN-W3", size: size)
    case "ko":
      // AppleSDGothicNeo is sans-serif, but commonly used.
      // For serif effect in Korean, usually "AppleMyungjo" is used on macOS/iOS if available, or fallback.
      return .custom("AppleMyungjo", size: size)
    default:
      return .system(size: size, design: .serif).weight(weight)
    }
  }
}
