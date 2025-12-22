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
  var width: CGFloat = PlatformHelper.dashboardCardWidth
  var layout: BrowseLayoutMode = .grid
  var onActionCompleted: (() -> Void)?

  var body: some View {
    switch layout {
    case .grid:
      CollectionCardView(
        komgaCollection: collection,
        width: width,
        onActionCompleted: onActionCompleted
      )
      .focusPadding()
    case .list:
      CollectionRowView(
        komgaCollection: collection,
        onActionCompleted: onActionCompleted
      )
    }
  }
}
