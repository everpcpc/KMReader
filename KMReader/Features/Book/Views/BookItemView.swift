//
// BookItemView.swift
//
//

import SwiftUI

struct BookItemView: View {
  let item: BookDisplayItem
  let layout: BrowseLayoutMode
  let onReadBook: (Bool) -> Void
  var onMutationCompleted: (() -> Void)? = nil
  var showSeriesTitle: Bool = true
  var showSeriesNavigation: Bool = true

  var body: some View {
    switch layout {
    case .grid:
      BookCardView(
        item: item,
        onReadBook: onReadBook,
        onMutationCompleted: onMutationCompleted,
        showSeriesTitle: showSeriesTitle,
        showSeriesNavigation: showSeriesNavigation
      )
    case .list:
      BookRowView(
        item: item,
        onReadBook: onReadBook,
        onMutationCompleted: onMutationCompleted,
        showSeriesTitle: showSeriesTitle,
        showSeriesNavigation: showSeriesNavigation
      )
    }
  }
}
