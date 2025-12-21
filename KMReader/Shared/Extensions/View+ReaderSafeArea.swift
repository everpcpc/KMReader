//
//  View+ReaderSafeArea.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftUI

extension View {
  /// Apply ignoresSafeArea only on iOS and tvOS platforms.
  /// On macOS, the view respects safe area.
  /// - Returns: View with ignoresSafeArea applied on iOS/tvOS, unchanged on macOS
  func readerIgnoresSafeArea() -> some View {
    #if os(iOS) || os(tvOS)
      return self.ignoresSafeArea()
    #else
      return self
    #endif
  }
}
