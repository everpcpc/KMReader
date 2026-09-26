//
// ShadowModifier.swift
//
//

import SwiftUI

struct ShadowModifier: ViewModifier {
  let style: ShadowStyle
  let cornerRadius: CGFloat

  @ViewBuilder
  func body(content: Content) -> some View {
    switch style {
    case .none:
      content
    case .basic:
      content
        .background(
          ShadowPathView(
            color: .shadowNear,
            radius: 2,
            x: 0,
            y: 0,
            cornerRadius: cornerRadius
          )
        )
    case .platform:
      content
        .background(
          ShadowPathView(
            color: .shadowFar,
            radius: 16,
            x: 0,
            y: 8,
            cornerRadius: cornerRadius
          )
        )
        .background(
          ShadowPathView(
            color: .shadowNear,
            radius: 4,
            x: 0,
            y: 4,
            cornerRadius: cornerRadius
          )
        )
    }
  }
}

extension View {
  func shadowStyle(_ style: ShadowStyle, cornerRadius: CGFloat = 0) -> some View {
    modifier(ShadowModifier(style: style, cornerRadius: cornerRadius))
  }
}
