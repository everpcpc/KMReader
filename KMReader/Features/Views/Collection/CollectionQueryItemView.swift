//
//  CollectionQueryItemView.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

/// Wrapper view that accepts only collectionId and uses @Query to fetch the collection reactively.
struct CollectionQueryItemView: View {
  let collectionId: String
  var layout: BrowseLayoutMode = .grid

  @Query private var komgaCollections: [KomgaCollection]

  init(
    collectionId: String,
    layout: BrowseLayoutMode = .grid
  ) {
    self.collectionId = collectionId
    self.layout = layout

    let compositeId = CompositeID.generate(id: collectionId)
    _komgaCollections = Query(filter: #Predicate<KomgaCollection> { $0.id == compositeId })
  }

  private var komgaCollection: KomgaCollection? {
    komgaCollections.first
  }

  var body: some View {
    if let collection = komgaCollection {
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
    } else {
      CardPlaceholder(layout: layout)
    }
  }
}
