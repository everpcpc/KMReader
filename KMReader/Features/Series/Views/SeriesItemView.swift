//
// SeriesItemView.swift
//
//

import SwiftUI

struct SeriesItemView: View {
  let item: SeriesDisplayItem
  let layout: BrowseLayoutMode
  var onMutationCompleted: (() -> Void)? = nil

  @State private var showDeleteConfirmation = false

  var body: some View {
    Group {
      switch layout {
      case .grid:
        SeriesCardView(
          item: item,
          onMutationCompleted: onMutationCompleted,
          onDeleteRequested: {
            showDeleteConfirmation = true
          }
        )
      case .list:
        SeriesRowView(
          item: item,
          onMutationCompleted: onMutationCompleted,
          onDeleteRequested: {
            showDeleteConfirmation = true
          }
        )
      }
    }
    .alert("Delete Series", isPresented: $showDeleteConfirmation) {
      Button("Cancel", role: .cancel) {}
      Button("Delete", role: .destructive) {
        deleteSeries()
      }
    } message: {
      Text("Are you sure you want to delete this series? This action cannot be undone.")
    }
  }

  private func deleteSeries() {
    Task {
      do {
        try await SeriesDeletionService.deleteSeries(item)
        ErrorManager.shared.notify(message: String(localized: "notification.series.deleted"))
        onMutationCompleted?()
      } catch {
        ErrorManager.shared.alert(error: error)
      }
    }
  }
}
