//
//  ThemeColor.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

// ThemeColor type that embeds Color and supports RawRepresentable
struct ThemeColor: RawRepresentable, Equatable, Hashable, Sendable {
  let color: Color

  nonisolated init(color: Color) {
    self.color = color
  }

  // Default orange color
  static nonisolated let orange = ThemeColor(color: .orange)

  // Convert ThemeColor to hex string
  nonisolated var rawValue: String {
    // Extract RGB components from Color in sRGB color space
    // Use CGColor to ensure consistent color space conversion
    let cgColor = PlatformHelper.cgColor(from: color)

    // Convert to sRGB color space if not already
    guard let sRGBColorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
      return "FF9500FF"  // Default to orange if sRGB color space unavailable
    }

    let convertedColor: CGColor
    if cgColor.colorSpace?.name == sRGBColorSpace.name {
      convertedColor = cgColor
    } else {
      guard
        let converted = cgColor.converted(
          to: sRGBColorSpace, intent: .defaultIntent, options: nil)
      else {
        return "FF9500FF"  // Default to orange if conversion fails
      }
      convertedColor = converted
    }

    guard let components = convertedColor.components,
      components.count >= 3
    else {
      return "FF9500FF"  // Default to orange if components unavailable
    }

    // Extract RGBA components (always in 0.0-1.0 range for sRGB)
    let r = components[0]
    let g = components.count > 1 ? components[1] : components[0]
    let b = components.count > 2 ? components[2] : components[0]
    let a = components.count > 3 ? components[3] : 1.0

    // Convert to 8-bit hex values (0-255) and format as ARGB hex string
    return String(
      format: "%02lX%02lX%02lX%02lX",
      lroundf(Float(a) * 255),  // Alpha first (ARGB format)
      lroundf(Float(r) * 255),
      lroundf(Float(g) * 255),
      lroundf(Float(b) * 255))
  }

  // Create ThemeColor from hex string
  nonisolated init?(rawValue: String) {
    // Parse hex color string
    let hex = rawValue.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var int: UInt64 = 0
    Scanner(string: hex).scanHexInt64(&int)
    let a: UInt64
    let r: UInt64
    let g: UInt64
    let b: UInt64
    switch hex.count {
    case 3:  // RGB (12-bit)
      (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
    case 6:  // RGB (24-bit)
      (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
    case 8:  // ARGB (32-bit)
      (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
    default:
      return nil
    }

    self.color = Color(
      .sRGB,
      red: Double(r) / 255,
      green: Double(g) / 255,
      blue: Double(b) / 255,
      opacity: Double(a) / 255
    )
  }

  // Convenience initializer from Color
  static func from(_ color: Color) -> ThemeColor {
    ThemeColor(color: color)
  }

  // Custom Equatable implementation using rawValue for reliable comparison
  static func == (lhs: ThemeColor, rhs: ThemeColor) -> Bool {
    return lhs.rawValue == rhs.rawValue
  }

  // Custom Hashable implementation using rawValue
  func hash(into hasher: inout Hasher) {
    hasher.combine(rawValue)
  }
}

#if os(tvOS)
  struct PresetColor {
    let name: String
    let color: Color
    let themeColor: ThemeColor

    init(name: String, color: Color) {
      self.name = name
      self.color = color
      self.themeColor = ThemeColor(color: color)
    }
  }

  extension ThemeColor {
    static let presetColors: [PresetColor] = [
      PresetColor(name: "Orange", color: .orange),
      PresetColor(name: "Red", color: .red),
      PresetColor(name: "Pink", color: .pink),
      PresetColor(name: "Purple", color: .purple),
      PresetColor(name: "Blue", color: .blue),
      PresetColor(name: "Cyan", color: .cyan),
      PresetColor(name: "Teal", color: .teal),
      PresetColor(name: "Green", color: .green),
      PresetColor(name: "Mint", color: .mint),
      PresetColor(name: "Yellow", color: .yellow),
      PresetColor(name: "Indigo", color: .indigo),
    ]
  }
#endif
