//
// ReadListItemQueryView.swift
//
//

import SwiftUI

struct ReadListItemQueryView: View {
  let item: ReadListDisplayItem
  var layout: BrowseLayoutMode = .grid
  var onMutationCompleted: (() -> Void)? = nil

  var body: some View {
    NavigationLink(value: NavDestination.readListDetail(readListId: item.readListId)) {
      switch layout {
      case .grid:
        ReadListCardView(
          item: item,
          onMutationCompleted: onMutationCompleted
        )
      case .list:
        ReadListRowView(
          item: item,
          onMutationCompleted: onMutationCompleted
        )
      }
    }
    .adaptiveButtonStyle(.plain)
  }
}
