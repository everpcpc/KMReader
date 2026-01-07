//
//  CollectionItemQueryView.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

struct CollectionItemQueryView: View {
  @Bindable var collection: KomgaCollection
  var layout: BrowseLayoutMode = .grid

  var body: some View {
    NavigationLink(value: NavDestination.collectionDetail(collectionId: collection.collectionId)) {
      switch layout {
      case .grid:
        CollectionCardView(
          komgaCollection: collection
        )
      case .list:
        CollectionRowView(
          komgaCollection: collection
        )
      }
    }
    .focusPadding()
    .adaptiveButtonStyle(.plain)
  }
}
