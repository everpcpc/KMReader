//
//  View+FocusPadding.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

extension View {
  /// Apply padding on tvOS platform for focus states.
  /// - On tvOS: applies padding
  /// - On other platforms: no-op
  func focusPadding(_ edges: Edge.Set = .all, _ length: CGFloat? = nil) -> some View {
    #if os(tvOS)
      if let length = length {
        return self.padding(edges, length)
      } else {
        return self.padding(edges)
      }
    #else
      return self
    #endif
  }
}
