//
// ReaderControlButtonStyle.swift
//
//

import SwiftUI

extension View {
  @ViewBuilder
  func readerControlButtonStyle() -> some View {
    #if os(iOS)
      if #available(iOS 26.0, *) {
        self.adaptiveButtonStyle(.bordered)
      } else {
        self
          .buttonStyle(.borderedProminent)
          .tint(.readerTint)
          .foregroundStyle(.white)
      }
    #else
      self.adaptiveButtonStyle(.bordered)
    #endif
  }
}
