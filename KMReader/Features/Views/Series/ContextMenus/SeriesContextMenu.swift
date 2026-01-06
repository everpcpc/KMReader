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
  @Bindable var komgaSeries: KomgaSeries

  var onActionCompleted: (() -> Void)?
  var onShowCollectionPicker: (() -> Void)? = nil
  var onDeleteRequested: (() -> Void)? = nil
  var onEditRequested: (() -> Void)? = nil

  @AppStorage("isAdmin") private var isAdmin: Bool = false
  @AppStorage("currentInstanceId") private var currentInstanceId: String = ""
  @AppStorage("isOffline") private var isOffline: Bool = false

  private var series: Series {
    komgaSeries.toSeries()
  }

  private var status: SeriesDownloadStatus {
    komgaSeries.downloadStatus
  }

  private var canMarkAsRead: Bool {
    series.booksUnreadCount > 0
  }

  private var canMarkAsUnread: Bool {
    (series.booksReadCount + series.booksInProgressCount) > 0
  }

  private var limitPresets: [Int] {
    [1, 3, 5, 10, 25, 50, 0]
  }

  var body: some View {
    Group {
      if !isOffline {

        if isAdmin {
          Button {
            onEditRequested?()
          } label: {
            Label("Edit", systemImage: "pencil")
          }
          Button {
            analyzeSeries()
          } label: {
            Label("Analyze", systemImage: "waveform.path.ecg")
          }
          Button {
            refreshMetadata()
          } label: {
            Label("Refresh Metadata", systemImage: "arrow.clockwise")
          }
          Divider()
        }

        Button {
          onShowCollectionPicker?()
        } label: {
          Label("Add to Collection", systemImage: "square.grid.2x2")
        }

        Divider()

        Menu {
          Button {
            updatePolicy(.manual)
          } label: {
            offlinePolicyLabel(.manual)
          }

          Menu {
            ForEach(limitPresets, id: \.self) { value in
              Button {
                updatePolicyAndLimit(.unreadOnly, limit: value)
              } label: {
                limitOptionLabel(policy: .unreadOnly, limit: value)
              }
            }
          } label: {
            offlinePolicyLabel(.unreadOnly)
          }

          Menu {
            ForEach(limitPresets, id: \.self) { value in
              Button {
                updatePolicyAndLimit(.unreadOnlyAndCleanupRead, limit: value)
              } label: {
                limitOptionLabel(policy: .unreadOnlyAndCleanupRead, limit: value)
              }
            }
          } label: {
            offlinePolicyLabel(.unreadOnlyAndCleanupRead)
          }

          Button {
            updatePolicy(.all)
          } label: {
            offlinePolicyLabel(.all)
          }
        } label: {
          Label("Offline Policy", systemImage: komgaSeries.offlinePolicy.icon)
        }

        Divider()

        Menu {
          actionsView(actions: SeriesDownloadAction.availableActions(for: status))
        } label: {
          Label("Download", systemImage: status.icon)
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
      // Sync books first if policy is not manual
      if policy != .manual {
        try? await SyncService.shared.syncAllSeriesBooks(seriesId: komgaSeries.seriesId)
      }
      await DatabaseOperator.shared.updateSeriesOfflinePolicy(
        seriesId: komgaSeries.seriesId, instanceId: currentInstanceId, policy: policy
      )
      await DatabaseOperator.shared.commit()
      await MainActor.run {
        onActionCompleted?()
      }
    }
  }

  private func updatePolicyAndLimit(_ policy: SeriesOfflinePolicy, limit: Int) {
    Task {
      try? await SyncService.shared.syncAllSeriesBooks(seriesId: komgaSeries.seriesId)
      await DatabaseOperator.shared.updateSeriesOfflinePolicy(
        seriesId: komgaSeries.seriesId,
        instanceId: currentInstanceId,
        policy: policy,
        limit: limit
      )
      await DatabaseOperator.shared.commit()
      await MainActor.run {
        onActionCompleted?()
      }
    }
  }

  @ViewBuilder
  private func actionsView(actions: [SeriesDownloadAction]) -> some View {
    ForEach(actions) { action in
      actionMenuItem(action: action)
    }
  }

  @ViewBuilder
  private func actionMenuItem(action: SeriesDownloadAction) -> some View {
    switch action {
    case .downloadUnread:
      Menu {
        downloadUnreadLimitOptions()
      } label: {
        Label(action.label(for: status), systemImage: action.icon(for: status))
      }
    default:
      Button(role: action.isDestructive ? .destructive : .none) {
        handleActionTap(action)
      } label: {
        Label(action.label(for: status), systemImage: action.icon(for: status))
      }
    }
  }

  private func handleActionTap(_ action: SeriesDownloadAction) {
    performAction(action)
  }

  private func handleDownloadUnreadTap(limit: Int) {
    downloadUnread(limit: limit)
  }

  @ViewBuilder
  private func offlinePolicyLabel(_ policy: SeriesOfflinePolicy) -> some View {
    let title = policy.title(limit: komgaSeries.offlinePolicyLimit)
    if policy == komgaSeries.offlinePolicy {
      Label(title, systemImage: "checkmark")
    } else {
      Label(policy.label, systemImage: policy.icon)
    }
  }

  @ViewBuilder
  private func downloadUnreadLimitOptions() -> some View {
    ForEach(limitPresets, id: \.self) { value in
      Button {
        handleDownloadUnreadTap(limit: value)
      } label: {
        Text(SeriesOfflinePolicy.limitTitle(value))
      }
    }
  }

  private func performAction(_ action: SeriesDownloadAction) {
    switch action {
    case .download:
      downloadAll()
    case .downloadUnread:
      downloadUnread(limit: komgaSeries.offlinePolicyLimit)
    case .removeRead:
      removeRead()
    case .remove, .cancel:
      removeAll()
    }
  }

  private func downloadAll() {
    Task {
      try? await SyncService.shared.syncAllSeriesBooks(seriesId: series.id)
      await DatabaseOperator.shared.downloadSeriesOffline(
        seriesId: series.id, instanceId: currentInstanceId
      )
      await DatabaseOperator.shared.commit()
      await MainActor.run {
        ErrorManager.shared.notify(
          message: String(localized: "notification.series.offlineDownloadQueued")
        )
        onActionCompleted?()
      }
    }
  }

  private func downloadUnread(limit: Int) {
    Task {
      try? await SyncService.shared.syncAllSeriesBooks(seriesId: series.id)
      await DatabaseOperator.shared.downloadSeriesUnreadOffline(
        seriesId: series.id,
        instanceId: currentInstanceId,
        limit: limit
      )
      await DatabaseOperator.shared.commit()
      await MainActor.run {
        ErrorManager.shared.notify(
          message: String(localized: "notification.series.offlineDownloadQueued")
        )
        onActionCompleted?()
      }
    }
  }

  private func removeRead() {
    Task {
      await DatabaseOperator.shared.removeSeriesReadOffline(
        seriesId: series.id, instanceId: currentInstanceId
      )
      await DatabaseOperator.shared.commit()
      await MainActor.run {
        ErrorManager.shared.notify(
          message: String(localized: "notification.series.offlineRemoved")
        )
        onActionCompleted?()
      }
    }
  }

  private func removeAll() {
    Task {
      await DatabaseOperator.shared.removeSeriesOffline(
        seriesId: series.id, instanceId: currentInstanceId
      )
      await DatabaseOperator.shared.commit()
      await MainActor.run {
        ErrorManager.shared.notify(
          message: String(localized: "notification.series.offlineRemoved")
        )
        onActionCompleted?()
      }
    }
  }

  @ViewBuilder
  private func limitOptionLabel(policy: SeriesOfflinePolicy, limit: Int) -> some View {
    let title = SeriesOfflinePolicy.limitTitle(limit)
    if komgaSeries.offlinePolicy == policy && komgaSeries.offlinePolicyLimit == limit {
      Label(title, systemImage: "checkmark")
    } else {
      Text(title)
    }
  }

}
