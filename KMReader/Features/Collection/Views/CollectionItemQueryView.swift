//
// CollectionItemQueryView.swift
//
//

import SwiftUI

struct CollectionItemQueryView: View {
  let item: CollectionDisplayItem
  var layout: BrowseLayoutMode = .grid
  var onMutationCompleted: (() -> Void)? = nil

  var body: some View {
    NavigationLink(value: NavDestination.collectionDetail(collectionId: item.collectionId)) {
      switch layout {
      case .grid:
        CollectionCardView(
          item: item,
          onMutationCompleted: onMutationCompleted
        )
      case .list:
        CollectionRowView(
          item: item,
          onMutationCompleted: onMutationCompleted
        )
      }
    }
    .adaptiveButtonStyle(.plain)
  }
}
