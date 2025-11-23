//
//  SeriesContextMenu.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

@MainActor
struct SeriesContextMenu: View {
  let series: Series
  var onActionCompleted: (() -> Void)?
  var onActionFailed: ((String) -> Void)?
  var onShowCollectionPicker: (() -> Void)? = nil

  private var canMarkAsRead: Bool {
    series.booksUnreadCount > 0
  }

  private var canMarkAsUnread: Bool {
    (series.booksReadCount + series.booksInProgressCount) > 0
  }

  var body: some View {
    Group {
      Button {
        analyzeSeries()
      } label: {
        Label("Analyze", systemImage: "waveform.path.ecg")
      }
      .disabled(!AppConfig.isAdmin)

      Button {
        refreshMetadata()
      } label: {
        Label("Refresh Metadata", systemImage: "arrow.clockwise")
      }
      .disabled(!AppConfig.isAdmin)

      Divider()

      Button {
        onShowCollectionPicker?()
      } label: {
        Label("Add to Collection", systemImage: "square.grid.2x2")
      }

      Divider()

      if canMarkAsRead {
        Button {
          markSeriesAsRead()
        } label: {
          Label("Mark as Read", systemImage: "checkmark.circle")
        }
      }

      if canMarkAsUnread {
        Button {
          markSeriesAsUnread()
        } label: {
          Label("Mark as Unread", systemImage: "circle")
        }
      }
    }
  }

  private func analyzeSeries() {
    Task {
      do {
        try await SeriesService.shared.analyzeSeries(seriesId: series.id)
        await MainActor.run {
          ErrorManager.shared.notify(message: "Series analysis started")
          onActionCompleted?()
        }
      } catch {
        await MainActor.run {
          onActionFailed?(error.localizedDescription)
        }
      }
    }
  }

  private func refreshMetadata() {
    Task {
      do {
        try await SeriesService.shared.refreshMetadata(seriesId: series.id)
        await MainActor.run {
          ErrorManager.shared.notify(message: "Series metadata refreshed")
          onActionCompleted?()
        }
      } catch {
        await MainActor.run {
          onActionFailed?(error.localizedDescription)
        }
      }
    }
  }

  private func markSeriesAsRead() {
    Task {
      do {
        try await SeriesService.shared.markAsRead(seriesId: series.id)
        await MainActor.run {
          ErrorManager.shared.notify(message: "Series marked as read")
          onActionCompleted?()
        }
      } catch {
        await MainActor.run {
          onActionFailed?(error.localizedDescription)
        }
      }
    }
  }

  private func markSeriesAsUnread() {
    Task {
      do {
        try await SeriesService.shared.markAsUnread(seriesId: series.id)
        await MainActor.run {
          ErrorManager.shared.notify(message: "Series marked as unread")
          onActionCompleted?()
        }
      } catch {
        await MainActor.run {
          onActionFailed?(error.localizedDescription)
        }
      }
    }
  }

  private func addToCollection(collectionId: String) {
    Task {
      do {
        try await CollectionService.shared.addSeriesToCollection(
          collectionId: collectionId,
          seriesIds: [series.id]
        )
        await MainActor.run {
          ErrorManager.shared.notify(message: "Series added to collection")
          onActionCompleted?()
        }
      } catch {
        await MainActor.run {
          onActionFailed?(error.localizedDescription)
        }
      }
    }
  }
}
