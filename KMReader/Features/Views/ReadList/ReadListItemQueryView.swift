//
//  ReadListItemQueryView.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

struct ReadListItemQueryView: View {
  @Bindable var readList: KomgaReadList
  var width: CGFloat?
  var layout: BrowseLayoutMode = .grid
  var onActionCompleted: (() -> Void)?

  @AppStorage("dashboardCardWidth") private var dashboardCardWidth: Double = Double(
    PlatformHelper.defaultDashboardCardWidth)

  private var cardWidth: CGFloat {
    width ?? CGFloat(dashboardCardWidth)
  }

  var body: some View {
    NavigationLink(value: NavDestination.readListDetail(readListId: readList.readListId)) {
      switch layout {
      case .grid:
        ReadListCardView(
          komgaReadList: readList,
          width: cardWidth,
          onActionCompleted: onActionCompleted
        )
      case .list:
        ReadListRowView(
          komgaReadList: readList,
          onActionCompleted: onActionCompleted
        )
      }
    }
    .focusPadding()
    .adaptiveButtonStyle(.plain)
  }
}
