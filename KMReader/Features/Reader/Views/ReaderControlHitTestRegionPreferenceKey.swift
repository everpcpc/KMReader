//
// ReaderControlHitTestRegionPreferenceKey.swift
//
//

import SwiftUI

struct ReaderControlHitTestRegionPreferenceKey: PreferenceKey {
  static var defaultValue: [CGRect] = []

  static func reduce(value: inout [CGRect], nextValue: () -> [CGRect]) {
    value.append(contentsOf: nextValue())
  }
}

extension View {
  func readerControlHitTestRegion() -> some View {
    background(
      GeometryReader { geometry in
        Color.clear.preference(
          key: ReaderControlHitTestRegionPreferenceKey.self,
          value: [geometry.frame(in: .global)]
        )
      }
    )
  }
}
