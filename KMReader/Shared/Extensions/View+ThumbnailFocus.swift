//
//  View+ThumbnailFocus.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

#if os(tvOS)
  private struct ThumbnailFocusModifier: ViewModifier {
    @FocusState private var isFocused: Bool
    let cornerRadius: CGFloat

    init(cornerRadius: CGFloat = 8) {
      self.cornerRadius = cornerRadius
    }

    func body(content: Content) -> some View {
      content
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
    }
  }
#endif

extension View {
  /// Adds focus highlight effect for thumbnail images on tvOS.
  /// - Parameter cornerRadius: The corner radius for the highlight border (default: 8)
  /// - Returns: View with focus highlight effect on tvOS, unchanged on other platforms
  @ViewBuilder
  func thumbnailFocus(cornerRadius: CGFloat = 8) -> some View {
    #if os(tvOS)
      modifier(ThumbnailFocusModifier(cornerRadius: cornerRadius))
    #else
      self
    #endif
  }
}
