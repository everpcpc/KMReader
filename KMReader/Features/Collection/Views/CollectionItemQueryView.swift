//
// CollectionItemQueryView.swift
//
//

import SwiftUI

struct CollectionItemQueryView: View {
  let collection: SeriesCollection
  var layout: BrowseLayoutMode = .grid

  var body: some View {
    NavigationLink(value: NavDestination.collectionDetail(collectionId: collection.id)) {
      switch layout {
      case .grid:
        CollectionCardView(
          collection: collection
        )
      case .list:
        CollectionRowView(
          collection: collection
        )
      }
    }
    .adaptiveButtonStyle(.plain)
  }
}
