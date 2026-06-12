//
// ReadListQueryItemView.swift
//
//

import SwiftUI

/// Wrapper view that accepts only readListId and fetches a read-list display projection.
struct ReadListQueryItemView: View {
  let readListId: String
  var layout: BrowseLayoutMode = .grid

  @AppStorage("currentAccount") private var current: Current = .init()
  @State private var item: ReadListDisplayItem?

  init(
    readListId: String,
    layout: BrowseLayoutMode = .grid
  ) {
    self.readListId = readListId
    self.layout = layout

  }

  var body: some View {
    Group {
      if let item {
        switch layout {
        case .grid:
          ReadListCardView(
            item: item,
            onMutationCompleted: reloadItem
          )
        case .list:
          ReadListRowView(
            item: item,
            onMutationCompleted: reloadItem
          )
        }
      } else {
        CardPlaceholder(layout: layout, kind: .readList)
      }
    }
    .task(id: "\(current.instanceId)|\(readListId)") {
      await loadItem()
    }
  }

  private func reloadItem() {
    Task {
      await loadItem()
    }
  }

  private func loadItem() async {
    guard let database = try? await DatabaseOperator.database() else {
      item = nil
      return
    }
    item = try? await database.fetchReadListDisplayItem(
      readListId: readListId,
      instanceId: current.instanceId
    )
  }
}
