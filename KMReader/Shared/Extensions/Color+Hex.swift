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
