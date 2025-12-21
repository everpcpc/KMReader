//
//  View+FocusableHighlight.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

#if os(tvOS)
  private struct TVFocusableHighlightModifier: ViewModifier {
    @FocusState private var isFocused: Bool

    func body(content: Content) -> some View {
      content
        .contentShape(Capsule())
        .animation(.easeInOut(duration: 0.15), value: isFocused)
        .focusable()
        .focused($isFocused)
        .listRowBackground(
          Capsule()
            .fill(isFocused ? Color.white.opacity(0.25) : Color.white.opacity(0.08))
        )
    }
  }
#endif

extension View {
  /// Adds a default highlight effect for focusable rows on tvOS.
  /// Helps indicate which label-only rows currently have focus.
  @ViewBuilder
  func tvFocusableHighlight() -> some View {
    #if os(tvOS)
      modifier(TVFocusableHighlightModifier())
    #else
      self
    #endif
  }
}
