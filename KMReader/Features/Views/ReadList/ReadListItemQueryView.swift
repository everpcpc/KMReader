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
  var width: CGFloat = PlatformHelper.dashboardCardWidth
  var layout: BrowseLayoutMode = .grid
  var onActionCompleted: (() -> Void)?

  var body: some View {
    switch layout {
    case .grid:
      ReadListCardView(
        komgaReadList: readList,
        width: width,
        onActionCompleted: onActionCompleted
      )
      .focusPadding()
    case .list:
      ReadListRowView(
        komgaReadList: readList,
        onActionCompleted: onActionCompleted
      )
    }
  }
}
