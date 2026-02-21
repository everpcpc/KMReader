//
// CollectionQueryItemView.swift
//
//

import SQLiteData
import SwiftUI

/// Wrapper view that accepts only collectionId and fetches the local record reactively.
struct CollectionQueryItemView: View {
  let collectionId: String
  var layout: BrowseLayoutMode = .grid

  @FetchAll private var collectionRecords: [KomgaCollectionRecord]

  init(
    collectionId: String,
    layout: BrowseLayoutMode = .grid
  ) {
    self.collectionId = collectionId
    self.layout = layout

    let instanceId = AppConfig.current.instanceId
    _collectionRecords = FetchAll(
      KomgaCollectionRecord.where { $0.instanceId.eq(instanceId) && $0.collectionId.eq(collectionId) }.limit(1)
    )
  }

  private var collection: SeriesCollection? {
    collectionRecords.first?.toCollection()
  }

  var body: some View {
    if let collection = collection {
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
    } else {
      CardPlaceholder(layout: layout, kind: .collection)
    }
  }
}
