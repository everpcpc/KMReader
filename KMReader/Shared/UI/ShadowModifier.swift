//
//  ShadowModifier.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct ShadowModifier: ViewModifier {
  let style: ShadowStyle
  let cornerRadius: CGFloat

  @Environment(\.colorScheme) private var colorScheme

  private var shadowColorNear: Color {
    if colorScheme == .light {
      return .black.opacity(0.4)
    } else {
      return .white.opacity(0.1)
    }
  }

  private var shadowColorFar: Color {
    if colorScheme == .light {
      return .black.opacity(0.1)
    } else {
      return .white.opacity(0.05)
    }
  }

  @ViewBuilder
  func body(content: Content) -> some View {
    switch style {
    case .none:
      content
    case .basic:
      content
        .background(
          ShadowPathView(
            color: shadowColorNear,
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
            color: shadowColorFar,
            radius: 16,
            x: 0,
            y: 8,
            cornerRadius: cornerRadius
          )
        )
        .background(
          ShadowPathView(
            color: shadowColorNear,
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
