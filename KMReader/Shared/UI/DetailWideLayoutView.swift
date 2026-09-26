//
// DetailWideLayoutView.swift
//
//

import SwiftUI

/// Wide detail layout (iPad regular width, macOS wide windows): the left
/// rail carries identity and about-info, the right column flows list
/// content. Rail and column scroll independently so the rail never scrolls
/// away with the list.
struct DetailWideLayoutView<Rail: View, Column: View>: View {
  let availableWidth: CGFloat
  @ViewBuilder let rail: (CGFloat) -> Rail
  @ViewBuilder let column: Column

  /// Rail takes the smaller golden-ratio slice of the detail column
  /// (width / φ² ≈ 38.2%), floored so narrow columns stay usable.
  private var railWidth: CGFloat {
    max(availableWidth * 0.382, 340)
  }

  /// Glass chips render their rim highlight only with a few points of room
  /// outside the capsule; flush against the rail's scroll bounds the rim is
  /// clipped away. The rail's scroll bounds reach this far into the empty
  /// space around the rail while leading padding and column spacing shrink
  /// by the same amount, so the visual grid is unchanged.
  private let railEffectMargin: CGFloat = 12

  var body: some View {
    HStack(alignment: .top, spacing: 28 - railEffectMargin) {
      ScrollView {
        rail(railWidth)
          .padding(.vertical)
      }
      .scrollIndicators(.hidden)
      .contentMargins(.horizontal, railEffectMargin, for: .scrollContent)
      .frame(width: railWidth + railEffectMargin * 2)

      ScrollView {
        column
          .padding(.vertical)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .padding(.leading, 24 - railEffectMargin)
    .padding(.trailing, 24)
  }
}
