//
// Color+Hex.swift
//
//

import SwiftUI

extension Color {
  init?(hex: String) {
    var trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.hasPrefix("#") {
      trimmed.removeFirst()
    }
    guard trimmed.count == 6, let value = Int(trimmed, radix: 16) else { return nil }
    let red = Double((value >> 16) & 0xFF) / 255.0
    let green = Double((value >> 8) & 0xFF) / 255.0
    let blue = Double(value & 0xFF) / 255.0
    self.init(red: red, green: green, blue: blue)
  }
}

#if os(iOS)
  import UIKit

  extension UIColor {
    convenience init?(hex: String) {
      var trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
      if trimmed.hasPrefix("#") {
        trimmed.removeFirst()
      }
      guard trimmed.count == 6, let value = Int(trimmed, radix: 16) else { return nil }
      let red = CGFloat((value >> 16) & 0xFF) / 255.0
      let green = CGFloat((value >> 8) & 0xFF) / 255.0
      let blue = CGFloat(value & 0xFF) / 255.0
      self.init(red: red, green: green, blue: blue, alpha: 1.0)
    }

    var brightness: CGFloat {
      var red: CGFloat = 0
      var green: CGFloat = 0
      var blue: CGFloat = 0
      var alpha: CGFloat = 0
      guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return 0 }
      return (red * 299 + green * 587 + blue * 114) / 1000
    }
  }
#elseif os(macOS)
  import AppKit

  extension NSColor {
    convenience init?(hex: String) {
      var trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
      if trimmed.hasPrefix("#") {
        trimmed.removeFirst()
      }
      guard trimmed.count == 6, let value = Int(trimmed, radix: 16) else { return nil }
      let red = CGFloat((value >> 16) & 0xFF) / 255.0
      let green = CGFloat((value >> 8) & 0xFF) / 255.0
      let blue = CGFloat(value & 0xFF) / 255.0
      self.init(red: red, green: green, blue: blue, alpha: 1.0)
    }
  }
#endif
