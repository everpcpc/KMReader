//
// SeriesItemView.swift
//
//

import SwiftUI

struct SeriesItemView: View {
  let item: SeriesDisplayItem
  let layout: BrowseLayoutMode
  var onMutationCompleted: (() -> Void)? = nil

  var body: some View {
    switch layout {
    case .grid:
      SeriesCardView(
        item: item,
        onMutationCompleted: onMutationCompleted
      )
    case .list:
      SeriesRowView(
        item: item,
        onMutationCompleted: onMutationCompleted
      )
    }
  }
}
