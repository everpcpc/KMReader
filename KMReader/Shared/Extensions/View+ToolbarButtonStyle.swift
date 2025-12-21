//
//  View+ToolbarButtonStyle.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

extension View {
  /// Apply optimized toolbar button style for tvOS.
  /// - On tvOS: applies larger font, frame, and padding for better TV navigation
  /// - On other platforms: no-op
  @ViewBuilder
  func toolbarButtonStyle() -> some View {
    #if os(tvOS)
      self
        .font(.title2)
        .frame(minWidth: 60, minHeight: 60)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    #else
      self
    #endif
  }
}
