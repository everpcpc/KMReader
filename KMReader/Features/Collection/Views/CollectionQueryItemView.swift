//
// CollectionQueryItemView.swift
//
//

import SwiftUI

/// Wrapper view that accepts only collectionId and fetches a collection display projection.
struct CollectionQueryItemView: View {
  let collectionId: String
  var layout: BrowseLayoutMode = .grid

  @AppStorage("currentAccount") private var current: Current = .init()
  @State private var item: CollectionDisplayItem?

  init(
    collectionId: String,
    layout: BrowseLayoutMode = .grid
  ) {
    self.collectionId = collectionId
    self.layout = layout

  }

  var body: some View {
    Group {
      if let item {
        switch layout {
        case .grid:
          CollectionCardView(
            item: item,
            onMutationCompleted: reloadItem
          )
        case .list:
          CollectionRowView(
            item: item,
            onMutationCompleted: reloadItem
          )
        }
      } else {
        CardPlaceholder(layout: layout, kind: .collection)
      }
    }
    .task(id: "\(current.instanceId)|\(collectionId)") {
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
    item = try? await database.fetchCollectionDisplayItem(
      collectionId: collectionId,
      instanceId: current.instanceId
    )
  }
}
