//
//  View+SheetPresentation.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

extension View {
  /// Apply platform-specific sheet presentation styling.
  /// - Parameters:
  ///   - detents: Presentation detents for iOS (default: `.medium, .large`)
  ///   - minWidth: Minimum width for macOS (default: 600)
  ///   - minHeight: Minimum height for macOS (default: 400)
  /// - On iOS: uses `.presentationDetents(detents)`
  /// - On macOS: uses `.frame(minWidth: minWidth, minHeight: minHeight)`
  /// - On tvOS: always uses `.presentationDetents([.large])`
  func platformSheetPresentation(
    detents: [PresentationDetent] = [.medium, .large],
    minWidth: CGFloat = 600,
    minHeight: CGFloat = 400
  ) -> some View {
    #if os(iOS)
      return self.presentationDetents(Set(detents))
    #elseif os(macOS)
      return self.frame(minWidth: minWidth, minHeight: minHeight)
    #elseif os(tvOS)
      return self.presentationDetents([.large])
    #else
      return self
    #endif
  }
}
