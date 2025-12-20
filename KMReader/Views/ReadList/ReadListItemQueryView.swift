//
//  ReadListItemQueryView.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

struct ReadListItemQueryView: View {

  let itemId: String
  var width: CGFloat = PlatformHelper.dashboardCardWidth
  var layout: BrowseLayoutMode = .grid
  var onActionCompleted: (() -> Void)?

  @Query private var readLists: [KomgaReadList]

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
    _readLists = Query(filter: #Predicate<KomgaReadList> { $0.id == compositeId })
  }

  var body: some View {
    if let readList = readLists.first {
      switch layout {
      case .grid:
        ReadListCardView(
          width: width,
          onActionCompleted: onActionCompleted
        )
        .environment(readList)
        .focusPadding()
      case .list:
        ReadListRowView(
          onActionCompleted: onActionCompleted
        )
        .environment(readList)
      }
    }
  }
}
