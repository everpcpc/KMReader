//
// View+TabBar.swift
//
//

import SwiftUI

extension View {
  @ViewBuilder
  func tabBarMinimizeBehaviorIfAvailable() -> some View {
    #if os(iOS)
      if #available(iOS 26.0, *) {
        self.tabBarMinimizeBehavior(.onScrollDown)
      } else {
        self
      }
    #else
      self
    #endif
  }
}
