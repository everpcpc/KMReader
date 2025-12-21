//
//  SeriesContextMenu.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

@MainActor
struct SeriesContextMenu: View {
  @Environment(KomgaSeries.self) private var komgaSeries

  var onActionCompleted: (() -> Void)?
  var onShowCollectionPicker: (() -> Void)? = nil
  var onDeleteRequested: (() -> Void)? = nil
  var onEditRequested: (() -> Void)? = nil

  @AppStorage("isAdmin") private var isAdmin: Bool = false
  @AppStorage("currentInstanceId") private var currentInstanceId: String = ""

  private var series: Series {
    komgaSeries.toSeries()
  }

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

      Menu {
        Picker(selection: Binding(
          get: { komgaSeries.offlinePolicy },
          set: { updatePolicy($0) }
        )) {
          ForEach(SeriesOfflinePolicy.allCases, id: \.self) { policy in
            Label(policy.label, systemImage: policy.icon)
              .tag(policy)
          }
        } label: {
          Text("Offline Policy")
        }
        .pickerStyle(.inline)

        Divider()

        Button(role: .destructive) {
          updatePolicy(.manual)
        } label: {
          Label(komgaSeries.downloadStatus.toggleLabel, systemImage: komgaSeries.downloadStatus.toggleIcon)
        }
      } label: {
        Label(komgaSeries.offlinePolicy.label, systemImage: komgaSeries.offlinePolicy.icon)
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
          ErrorManager.shared.notify(
            message: String(localized: "notification.series.analysisStarted"))
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
          ErrorManager.shared.notify(
            message: String(localized: "notification.series.metadataRefreshed"))
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
          ErrorManager.shared.notify(
            message: String(localized: "notification.series.addedToCollection"))
          onActionCompleted?()
        }
      } catch {
        await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
    }
  }

  private func updatePolicy(_ policy: SeriesOfflinePolicy) {
    Task {
      await DatabaseOperator.shared.updateSeriesOfflinePolicy(
        seriesId: komgaSeries.seriesId, instanceId: currentInstanceId, policy: policy
      )
      try? await DatabaseOperator.shared.commit()
      await MainActor.run {
        onActionCompleted?()
      }
    }
  }
}
