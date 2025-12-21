//
//  ReadListItemQueryView.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

struct ReadListItemQueryView: View {
  @Environment(KomgaReadList.self) private var readList
  var width: CGFloat = PlatformHelper.dashboardCardWidth
  var layout: BrowseLayoutMode = .grid
  var onActionCompleted: (() -> Void)?

  var body: some View {
    switch layout {
    case .grid:
      ReadListCardView(
        width: width,
        onActionCompleted: onActionCompleted
      )
      .focusPadding()
    case .list:
      ReadListRowView(
        onActionCompleted: onActionCompleted
      )
    }
  }
}
