//
// ReadListItemQueryView.swift
//
//

import SwiftUI

struct ReadListItemQueryView: View {
  let readList: ReadList
  let localState: KomgaReadListLocalStateRecord?
  var layout: BrowseLayoutMode = .grid

  var body: some View {
    NavigationLink(value: NavDestination.readListDetail(readListId: readList.id)) {
      switch layout {
      case .grid:
        ReadListCardView(
          readList: readList,
          localState: localState
        )
      case .list:
        ReadListRowView(
          readList: readList,
          localState: localState
        )
      }
    }
    .adaptiveButtonStyle(.plain)
  }
}
