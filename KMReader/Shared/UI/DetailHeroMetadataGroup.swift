//
// DetailHeroMetadataGroup.swift
//
//

import Flow
import SwiftUI

/// Container for a hero's metadata rows: a centered wrapping flow in the
/// centered hero, plain rows (direct children of the info stack) otherwise.
struct DetailHeroMetadataGroup<Content: View>: View {
  @ViewBuilder let content: Content

  @Environment(\.detailHeroCentered) private var isCentered

  var body: some View {
    if isCentered {
      HFlow(
        horizontalAlignment: .center,
        verticalAlignment: .center,
        horizontalSpacing: 12,
        verticalSpacing: 8
      ) {
        content
      }
    } else {
      content
    }
  }
}
