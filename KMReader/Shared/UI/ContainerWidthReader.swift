//
//  ContainerWidthReader.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftUI

private struct ContainerWidthReaderModifier: ViewModifier {
  let epsilon: CGFloat
  let action: (CGFloat) -> Void

  @State private var lastWidth: CGFloat?

  func body(content: Content) -> some View {
    GeometryReader { geometry in
      content
        .onChange(of: geometry.size.width, initial: true) { _, newWidth in
          let resolvedWidth = max(0, newWidth)
          guard PlatformHelper.isValidWidth(resolvedWidth) else { return }
          if let lastWidth, abs(lastWidth - resolvedWidth) < epsilon {
            return
          }
          lastWidth = resolvedWidth
          action(resolvedWidth)
        }
    }
  }
}

extension View {
  /// Observe the parent container width without relying on content sizing.
  func onContainerWidthChange(
    epsilon: CGFloat = 1,
    _ action: @escaping (CGFloat) -> Void
  ) -> some View {
    modifier(ContainerWidthReaderModifier(epsilon: epsilon, action: action))
  }
}
