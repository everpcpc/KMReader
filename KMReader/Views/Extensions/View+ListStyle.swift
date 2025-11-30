//
//  View+ListStyle.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

extension View {
  /// Apply optimized list style for each platform.
  /// - iOS: uses `.insetGrouped` for a modern, spacious look
  /// - macOS: uses `.inset(alternatesRowBackgrounds: true)` for better readability
  /// - tvOS: uses `.plain` with `.focusSection()` for TV navigation
  func optimizedListStyle(alternatesRowBackgrounds: Bool = false) -> some View {
    #if os(iOS)
      return self.listStyle(.insetGrouped)
    #elseif os(macOS)
      return self.listStyle(.inset(alternatesRowBackgrounds: alternatesRowBackgrounds))
    #elseif os(tvOS)
      return self.listStyle(.plain).focusSection()
    #else
      return self.listStyle(.plain)
    #endif
  }
}
