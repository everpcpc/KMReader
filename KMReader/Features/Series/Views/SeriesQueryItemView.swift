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
  @State private var projectionReloadTask: Task<Void, Never>?

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
      guard notification.userInfo?["seriesId"] as? String == seriesId else { return }
      scheduleProjectionReload(after: ContentProjectionNotifier.refreshDelay(from: notification))
    }
    .onDisappear {
      cancelProjectionReload()
    }
  }

  private func reloadItem() {
    Task {
      await loadItem()
    }
  }

  private func scheduleProjectionReload(
    after delay: UInt64 = ContentProjectionNotifier.localRefreshDelay
  ) {
    cancelProjectionReload()

    projectionReloadTask = Task { @MainActor in
      do {
        try await Task.sleep(nanoseconds: delay)
      } catch {
        return
      }

      guard !Task.isCancelled else { return }
      await loadItem()
      projectionReloadTask = nil
    }
  }

  private func cancelProjectionReload() {
    projectionReloadTask?.cancel()
    projectionReloadTask = nil
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
