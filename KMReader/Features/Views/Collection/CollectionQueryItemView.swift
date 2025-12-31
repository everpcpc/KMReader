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
  var onActionCompleted: (() -> Void)?

  @Query private var komgaCollections: [KomgaCollection]

  init(
    collectionId: String,
    layout: BrowseLayoutMode = .grid,
    onActionCompleted: (() -> Void)? = nil
  ) {
    self.collectionId = collectionId
    self.layout = layout
    self.onActionCompleted = onActionCompleted

    let instanceId = AppConfig.currentInstanceId
    let compositeId = "\(instanceId)_\(collectionId)"
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
          komgaCollection: collection,
          onActionCompleted: onActionCompleted
        )
      case .list:
        CollectionRowView(
          komgaCollection: collection,
          onActionCompleted: onActionCompleted
        )
      }
    } else {
      CardPlaceholder(layout: layout)
    }
  }
}
