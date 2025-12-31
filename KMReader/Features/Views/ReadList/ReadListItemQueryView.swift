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
  var layout: BrowseLayoutMode = .grid
  var onActionCompleted: (() -> Void)?

  var body: some View {
    NavigationLink(value: NavDestination.readListDetail(readListId: readList.readListId)) {
      switch layout {
      case .grid:
        ReadListCardView(
          komgaReadList: readList,
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
