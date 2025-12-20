//
//  CollectionItemQueryView.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

struct CollectionItemQueryView: View {
  @Environment(KomgaCollection.self) private var collection
  var width: CGFloat = PlatformHelper.dashboardCardWidth
  var layout: BrowseLayoutMode = .grid
  var onActionCompleted: (() -> Void)?

  var body: some View {
    switch layout {
    case .grid:
      CollectionCardView(
        width: width,
        onActionCompleted: onActionCompleted
      )
      .focusPadding()
    case .list:
      CollectionRowView(
        onActionCompleted: onActionCompleted
      )
    }
  }
}
