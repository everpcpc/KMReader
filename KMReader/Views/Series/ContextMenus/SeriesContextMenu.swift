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
  var onShowCollectionPicker: (() -> Void)? = nil
  var onDeleteRequested: (() -> Void)? = nil
  var onEditRequested: (() -> Void)? = nil
  @AppStorage("isAdmin") private var isAdmin: Bool = false

  private var canMarkAsRead: Bool {
    series.booksUnreadCount > 0
  }

  private var canMarkAsUnread: Bool {
    (series.booksReadCount + series.booksInProgressCount) > 0
  }

  var body: some View {
    Group {
      Menu {
        Button {
          onEditRequested?()
        } label: {
          Label("Edit", systemImage: "pencil")
        }
        .disabled(!isAdmin)

        Divider()

        Button {
          analyzeSeries()
        } label: {
          Label("Analyze", systemImage: "waveform.path.ecg")
        }
        .disabled(!isAdmin)

        Button {
          refreshMetadata()
        } label: {
          Label("Refresh Metadata", systemImage: "arrow.clockwise")
        }
        .disabled(!isAdmin)

        Divider()

        Button {
          onShowCollectionPicker?()
        } label: {
          Label("Add to Collection", systemImage: "square.grid.2x2")
        }

        Divider()

        Button(role: .destructive) {
          onDeleteRequested?()
        } label: {
          Label("Delete", systemImage: "trash")
        }
        .disabled(!isAdmin)
      } label: {
        Label("Manage", systemImage: "gearshape")
      }
      .disabled(!isAdmin)

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
          ErrorManager.shared.notify(message: String(localized: "notification.series.analysisStarted"))
          onActionCompleted?()
        }
      } catch {
        await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
    }
  }

  private func refreshMetadata() {
    Task {
      do {
        try await SeriesService.shared.refreshMetadata(seriesId: series.id)
        await MainActor.run {
          ErrorManager.shared.notify(message: String(localized: "notification.series.metadataRefreshed"))
          onActionCompleted?()
        }
      } catch {
        await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
    }
  }

  private func markSeriesAsRead() {
    Task {
      do {
        try await SeriesService.shared.markAsRead(seriesId: series.id)
        await MainActor.run {
          ErrorManager.shared.notify(message: String(localized: "notification.series.markedRead"))
          onActionCompleted?()
        }
      } catch {
        await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
    }
  }

  private func markSeriesAsUnread() {
    Task {
      do {
        try await SeriesService.shared.markAsUnread(seriesId: series.id)
        await MainActor.run {
          ErrorManager.shared.notify(message: String(localized: "notification.series.markedUnread"))
          onActionCompleted?()
        }
      } catch {
        await MainActor.run {
          ErrorManager.shared.alert(error: error)
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
          ErrorManager.shared.notify(message: String(localized: "notification.series.addedToCollection"))
          onActionCompleted?()
        }
      } catch {
        await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
    }
  }
}
