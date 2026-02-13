//
//  View+PickerStyle.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

extension View {
  /// Apply optimized picker style for each platform.
  /// - iOS: uses `.segmented` for a modern, spacious look
  /// - macOS: uses `.radioGroup` for better readability
  /// - tvOS: uses `.segmented` for TV navigation
  func optimizedPickerStyle() -> some View {
    #if os(iOS)
      return self.pickerStyle(.segmented)
    #elseif os(macOS)
      // NOTE: bug on macOS with segmented picker + List
      // could cause error: AttributeGraph: cycle detected through attribute
      return self.pickerStyle(.menu)
    #else
      return self.pickerStyle(.segmented)
    #endif
  }
}
