//
//  AdaptiveButtonStyle.swift
//  Komga
//
//

import SwiftUI

extension View {
  @ViewBuilder
  func textSelectionIfAvailable() -> some View {
    #if os(tvOS)
      self
    #else
      self.textSelection(.enabled)
    #endif
  }
}
