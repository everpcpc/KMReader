//
//  View+ControlSize.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

extension View {
  /// Apply optimized control size for each platform.
  /// - iOS: uses `.regular` for iPad and `.mini` for iPhone
  /// - macOS: uses `.regular`
  /// - tvOS: uses `.regular`
  func optimizedControlSize() -> some View {
    #if os(iOS)
      if PlatformHelper.isPad {
        return self.controlSize(.regular).font(.body)
      } else {
        return self.controlSize(.mini).font(.footnote)
      }
    #else
      return self.controlSize(.regular).font(.body)
    #endif
  }
}
