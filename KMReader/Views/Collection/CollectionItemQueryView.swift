//
//  CollectionItemQueryView.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

struct CollectionItemQueryView: View {

  let itemId: String
  var width: CGFloat = PlatformHelper.dashboardCardWidth
  var layout: BrowseLayoutMode = .grid
  var onActionCompleted: (() -> Void)?

  @Query private var collections: [KomgaCollection]

  init(
    itemId: String,
    width: CGFloat = PlatformHelper.dashboardCardWidth,
    layout: BrowseLayoutMode = .grid,
    onActionCompleted: (() -> Void)? = nil
  ) {
    self.itemId = itemId
    self.width = width
    self.layout = layout
    self.onActionCompleted = onActionCompleted

    let instanceId = AppConfig.currentInstanceId
    let compositeId = "\(instanceId)_\(itemId)"
    _collections = Query(filter: #Predicate<KomgaCollection> { $0.id == compositeId })
  }

  var body: some View {
    if let collection = collections.first {
      switch layout {
      case .grid:
        CollectionCardView(
          width: width,
          onActionCompleted: onActionCompleted
        )
        .environment(collection)
        .focusPadding()
      case .list:
        CollectionRowView(
          onActionCompleted: onActionCompleted
        )
        .environment(collection)
      }
    }
  }
}
