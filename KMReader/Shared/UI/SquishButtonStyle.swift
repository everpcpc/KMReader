//
//  SquishButtonStyle.swift
//  KMReader
//
//  Created by KMReader iOS Client
//

import SwiftUI

/// A button style that provides a soft, squishy press effect
struct SquishButtonStyle: ButtonStyle {
  var scale: CGFloat = 0.95

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? scale : 1.0)
      .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
  }
}

extension ButtonStyle where Self == SquishButtonStyle {
  static var squish: SquishButtonStyle { SquishButtonStyle() }

  static func squish(scale: CGFloat) -> SquishButtonStyle {
    SquishButtonStyle(scale: scale)
  }
}
