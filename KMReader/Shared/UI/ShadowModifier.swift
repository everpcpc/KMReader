//
//  ShadowModifier.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct ShadowModifier: ViewModifier {
  let style: ShadowStyle

  @Environment(\.colorScheme) private var colorScheme

  private var shadowColorNear: Color {
    if colorScheme == .light {
      return .black.opacity(0.4)
    } else {
      return .white.opacity(0.4)
    }
  }

  private var shadowColorFar: Color {
    if colorScheme == .light {
      return .black.opacity(0.1)
    } else {
      return .white.opacity(0.1)
    }
  }

  @ViewBuilder
  func body(content: Content) -> some View {
    switch style {
    case .none:
      content
    case .basic:
      content
        .shadow(color: shadowColorNear, radius: 2)
    case .platform:
      content
        .shadow(color: shadowColorFar, radius: 16, x: 0, y: 8)
        .shadow(color: shadowColorNear, radius: 4, x: 0, y: 4)
    }
  }
}

extension View {
  func shadowStyle(_ style: ShadowStyle) -> some View {
    modifier(ShadowModifier(style: style))
  }
}
