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
  var width: CGFloat?
  var layout: BrowseLayoutMode = .grid
  var onActionCompleted: (() -> Void)?

  @AppStorage("dashboardCardWidth") private var dashboardCardWidth: Double = Double(
    PlatformHelper.defaultDashboardCardWidth)

  private var cardWidth: CGFloat {
    width ?? CGFloat(dashboardCardWidth)
  }

  var body: some View {
    switch layout {
    case .grid:
      CollectionCardView(
        komgaCollection: collection,
        width: cardWidth,
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
