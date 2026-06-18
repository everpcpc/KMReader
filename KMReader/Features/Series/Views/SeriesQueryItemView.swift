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
    .onReceive(NotificationCenter.default.publisher(for: .seriesProjectionDidChange)) {
      notification in
      guard shouldReload(for: notification) else { return }
      reloadItem()
    }
  }

  private func shouldReload(for notification: Notification) -> Bool {
    let changedIds = changedSeriesIds(from: notification)
    guard !changedIds.isEmpty else { return true }
    return changedIds.contains(seriesId)
  }

  private func changedSeriesIds(from notification: Notification) -> Set<String> {
    if let ids = notification.userInfo?["seriesIds"] as? Set<String> {
      return ids
    }
    if let ids = notification.userInfo?["seriesIds"] as? [String] {
      return Set(ids)
    }
    if let id = notification.userInfo?["seriesId"] as? String {
      return [id]
    }
    return []
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
