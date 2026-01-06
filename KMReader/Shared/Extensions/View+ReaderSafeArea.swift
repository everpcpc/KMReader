//
//  View+ReaderSafeArea.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftUI

extension View {
  /// Apply ignoresSafeArea only on iOS.
  /// On macOS, the view respects safe area.
  /// - Returns: View with ignoresSafeArea applied on iOS, unchanged on other platforms
  func readerIgnoresSafeArea() -> some View {
    #if os(iOS) || os(tvOS)
      return self.ignoresSafeArea()
    #else
      return self
    #endif
  }
}

extension View {
  @ViewBuilder
  func iPadIgnoresSafeArea(paddingTop: CGFloat = 0)
    -> some View
  {
    #if os(iOS)
      if PlatformHelper.isPad {
        self.padding(.top, paddingTop).ignoresSafeArea()
      } else {
        self
      }
    #else
      self
    #endif
  }
}
