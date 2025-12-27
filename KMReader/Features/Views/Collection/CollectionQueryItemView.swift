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
  var width: CGFloat?
  var layout: BrowseLayoutMode = .grid
  var onActionCompleted: (() -> Void)?

  @AppStorage("dashboardCardWidth") private var dashboardCardWidth: Double = Double(
    PlatformHelper.defaultDashboardCardWidth)
  @Query private var komgaCollections: [KomgaCollection]

  init(
    collectionId: String,
    width: CGFloat? = nil,
    layout: BrowseLayoutMode = .grid,
    onActionCompleted: (() -> Void)? = nil
  ) {
    self.collectionId = collectionId
    self.width = width
    self.layout = layout
    self.onActionCompleted = onActionCompleted

    let instanceId = AppConfig.currentInstanceId
    let compositeId = "\(instanceId)_\(collectionId)"
    _komgaCollections = Query(filter: #Predicate<KomgaCollection> { $0.id == compositeId })
  }

  private var komgaCollection: KomgaCollection? {
    komgaCollections.first
  }

  private var cardWidth: CGFloat {
    width ?? CGFloat(dashboardCardWidth)
  }

  var body: some View {
    if let collection = komgaCollection {
      switch layout {
      case .grid:
        CollectionCardView(
          komgaCollection: collection,
          width: cardWidth,
          onActionCompleted: onActionCompleted
        )
      case .list:
        CollectionRowView(
          komgaCollection: collection,
          onActionCompleted: onActionCompleted
        )
      }
    }
  }
}
