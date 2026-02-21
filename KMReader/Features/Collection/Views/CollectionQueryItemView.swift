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

  @FetchAll private var komgaCollections: [KomgaCollectionRecord]

  init(
    collectionId: String,
    layout: BrowseLayoutMode = .grid
  ) {
    self.collectionId = collectionId
    self.layout = layout

    let instanceId = AppConfig.current.instanceId
    _komgaCollections = FetchAll(
      KomgaCollectionRecord.where { $0.instanceId.eq(instanceId) && $0.collectionId.eq(collectionId) }
    )
  }

  private var komgaCollection: KomgaCollection? {
    komgaCollections.first?.toKomgaCollection()
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
      CardPlaceholder(layout: layout, kind: .collection)
    }
  }
}
