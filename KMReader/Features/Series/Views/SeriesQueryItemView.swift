//
// SeriesQueryItemView.swift
//
//

import SwiftUI

/// Wrapper view that accepts only seriesId and fetches a series display projection.
struct SeriesQueryItemView: View {
  let seriesId: String
  let layout: BrowseLayoutMode

  @AppStorage("currentAccount") private var current: Current = .init()
  @State private var item: SeriesDisplayItem?

  init(
    seriesId: String,
    layout: BrowseLayoutMode
  ) {
    self.seriesId = seriesId
    self.layout = layout

  }

  var body: some View {
    Group {
      if let item {
        switch layout {
        case .grid:
          SeriesCardView(
            item: item,
            onMutationCompleted: reloadItem
          )
        case .list:
          SeriesRowView(
            item: item,
            onMutationCompleted: reloadItem
          )
        }
      } else {
        CardPlaceholder(layout: layout, kind: .series)
      }
    }
    .task(id: "\(current.instanceId)|\(seriesId)") {
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
    item = try? await database.fetchSeriesDisplayItem(
      seriesId: seriesId,
      instanceId: current.instanceId
    )
  }
}
