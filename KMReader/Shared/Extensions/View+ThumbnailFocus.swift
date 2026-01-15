//
//  View+ThumbnailFocus.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

private struct ThumbnailFocusModifier: ViewModifier {
  #if os(tvOS)
    @FocusState private var isFocused: Bool
  #endif
  @AppStorage("thumbnailGlassEffect") private var thumbnailGlassEffect: Bool = false

  let cornerRadius: CGFloat

  init(cornerRadius: CGFloat = 8) {
    self.cornerRadius = cornerRadius
  }

  func body(content: Content) -> some View {
    content
      .glassEffectIfAvailable(enabled: thumbnailGlassEffect, in: RoundedRectangle(cornerRadius: cornerRadius))
      #if os(tvOS)
        .focusable()
        .focused($isFocused)
        .overlay {
          if isFocused {
            RoundedRectangle(cornerRadius: cornerRadius)
            .stroke(Color.white, lineWidth: 4)
            .shadow(color: Color.white.opacity(0.8), radius: 8)
          }
        }
        .scaleEffect(isFocused ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isFocused)
      #endif
  }
}

extension View {
  /// Adds focus highlight effect for thumbnail images on tvOS and optional glass effect on all platforms.
  /// - Parameter cornerRadius: The corner radius for the highlight border and glass effect (default: 8)
  /// - Returns: View with focus highlight effect on tvOS and optional glass effect based on settings
  @ViewBuilder
  func thumbnailFocus(cornerRadius: CGFloat = 8) -> some View {
    modifier(ThumbnailFocusModifier(cornerRadius: cornerRadius))
  }
}
