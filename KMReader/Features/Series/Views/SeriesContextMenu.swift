//
//  SeriesContextMenu.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct SeriesContextMenu: View {
  let seriesId: String
  let menuTitle: String
  let downloadStatus: SeriesDownloadStatus
  let offlinePolicy: SeriesOfflinePolicy
  let offlinePolicyLimit: Int
  let booksUnreadCount: Int
  let booksReadCount: Int
  let booksInProgressCount: Int

  var onShowCollectionPicker: (() -> Void)? = nil
  var onDeleteRequested: (() -> Void)? = nil
  var onEditRequested: (() -> Void)? = nil

  @AppStorage("currentAccount") private var current: Current = .init()
  @AppStorage("isOffline") private var isOffline: Bool = false

  @Environment(\.modelContext) private var modelContext
  @Environment(ReaderPresentationManager.self) private var readerPresentation

  private var status: SeriesDownloadStatus {
    downloadStatus
  }

  private var canRead: Bool {
    booksUnreadCount + booksInProgressCount > 0
  }

  private var readLabel: String {
    if booksReadCount > 0 {
      return String(localized: "Resume Reading")
    } else {
      return String(localized: "Start Reading")
    }
  }

  private var canMarkAsRead: Bool {
    booksUnreadCount > 0
  }

  private var canMarkAsUnread: Bool {
    (booksReadCount + booksInProgressCount) > 0
  }

  private var limitPresets: [Int] {
    [1, 3, 5, 10, 25, 50, 0]
  }

  var body: some View {
    Group {
      Button(action: {}) {
        Text(menuTitle.isEmpty ? "Untitled" : menuTitle)
          .font(.footnote)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }
      .disabled(true)
      Divider()

      if canRead {
        Button {
          continueReading()
        } label: {
          Label(readLabel, systemImage: "play")
        }
        Divider()
      }

      if !isOffline {
        Button {
          onShowCollectionPicker?()
        } label: {
          Label("Add to Collection", systemImage: ContentIcon.collection)
        }

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

        Divider()

        if current.isAdmin {
          Menu {
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

            if onDeleteRequested != nil {
              Divider()
              Button(role: .destructive) {
                onDeleteRequested?()
              } label: {
                Label("Delete Series", systemImage: "trash")
              }
            }
          } label: {
            Label("Manage", systemImage: "gearshape")
          }

          Divider()
        }
      }

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
        Label("Offline Policy", systemImage: offlinePolicy.icon)
      }

      Menu {
        actionsView(actions: SeriesDownloadAction.availableActions(for: status))
      } label: {
        Label("Download", systemImage: status.icon)
      }

      if !isOffline {
        Divider()
        Button {
          refreshCover()
        } label: {
          Label("Refresh Cover", systemImage: "arrow.clockwise")
        }
      }
    }
  }

  private func refreshCover() {
    Task {
      do {
        try await ThumbnailCache.refreshThumbnail(id: seriesId, type: .series)
        ErrorManager.shared.notify(message: String(localized: "notification.series.coverRefreshed"))
      } catch {
        ErrorManager.shared.alert(error: error)
      }
    }
  }

  private func continueReading() {
    Task {
      let book = await SeriesContinueReadingResolver.resolve(
        seriesId: seriesId,
        isOffline: isOffline,
        context: modelContext
      )
      if let book {
        readerPresentation.present(book: book, incognito: false)
      }
    }
  }

  private func analyzeSeries() {
    Task {
      do {
        try await SeriesService.shared.analyzeSeries(seriesId: seriesId)
        ErrorManager.shared.notify(
          message: String(localized: "notification.series.analysisStarted"))
      } catch {
        ErrorManager.shared.alert(error: error)
      }
    }
  }

  private func refreshMetadata() {
    Task {
      do {
        try await SeriesService.shared.refreshMetadata(seriesId: seriesId)
        ErrorManager.shared.notify(
          message: String(localized: "notification.series.metadataRefreshed"))
      } catch {
        ErrorManager.shared.alert(error: error)
      }
    }
  }

  private func markSeriesAsRead() {
    Task {
      do {
        try await SeriesService.shared.markAsRead(seriesId: seriesId)
        ErrorManager.shared.notify(message: String(localized: "notification.series.markedRead"))
      } catch {
        ErrorManager.shared.alert(error: error)
      }
    }
  }

  private func markSeriesAsUnread() {
    Task {
      do {
        try await SeriesService.shared.markAsUnread(seriesId: seriesId)
        ErrorManager.shared.notify(message: String(localized: "notification.series.markedUnread"))
      } catch {
        ErrorManager.shared.alert(error: error)
      }
    }
  }

  private func addToCollection(collectionId: String) {
    Task {
      do {
        try await CollectionService.shared.addSeriesToCollection(
          collectionId: collectionId,
          seriesIds: [seriesId]
        )
        ErrorManager.shared.notify(
          message: String(localized: "notification.series.addedToCollection"))
      } catch {
        ErrorManager.shared.alert(error: error)
      }
    }
  }

  private func updatePolicy(_ policy: SeriesOfflinePolicy) {
    Task {
      // Sync books first if policy is not manual
      if policy != .manual {
        try? await SyncService.shared.syncAllSeriesBooks(seriesId: seriesId)
      }
      await DatabaseOperator.shared.updateSeriesOfflinePolicy(
        seriesId: seriesId, instanceId: current.instanceId, policy: policy
      )
      await DatabaseOperator.shared.commit()
    }
  }

  private func updatePolicyAndLimit(_ policy: SeriesOfflinePolicy, limit: Int) {
    Task {
      try? await SyncService.shared.syncAllSeriesBooks(seriesId: seriesId)
      await DatabaseOperator.shared.updateSeriesOfflinePolicy(
        seriesId: seriesId,
        instanceId: current.instanceId,
        policy: policy,
        limit: limit
      )
      await DatabaseOperator.shared.commit()
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
    let title = policy.title(limit: offlinePolicyLimit)
    if policy == offlinePolicy {
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
      downloadUnread(limit: offlinePolicyLimit)
    case .removeRead:
      removeRead()
    case .remove, .cancel:
      removeAll()
    }
  }

  private func downloadAll() {
    Task {
      try? await SyncService.shared.syncAllSeriesBooks(seriesId: seriesId)
      await DatabaseOperator.shared.downloadSeriesOffline(
        seriesId: seriesId, instanceId: current.instanceId
      )
      await DatabaseOperator.shared.commit()
      ErrorManager.shared.notify(
        message: String(localized: "notification.series.offlineDownloadQueued")
      )
    }
  }

  private func downloadUnread(limit: Int) {
    Task {
      try? await SyncService.shared.syncAllSeriesBooks(seriesId: seriesId)
      await DatabaseOperator.shared.downloadSeriesUnreadOffline(
        seriesId: seriesId,
        instanceId: current.instanceId,
        limit: limit
      )
      await DatabaseOperator.shared.commit()
      ErrorManager.shared.notify(
        message: String(localized: "notification.series.offlineDownloadQueued")
      )
    }
  }

  private func removeRead() {
    Task {
      await DatabaseOperator.shared.removeSeriesReadOffline(
        seriesId: seriesId, instanceId: current.instanceId
      )
      await DatabaseOperator.shared.commit()
      ErrorManager.shared.notify(
        message: String(localized: "notification.series.offlineRemoved")
      )
    }
  }

  private func removeAll() {
    Task {
      await DatabaseOperator.shared.removeSeriesOffline(
        seriesId: seriesId, instanceId: current.instanceId
      )
      await DatabaseOperator.shared.commit()
      ErrorManager.shared.notify(
        message: String(localized: "notification.series.offlineRemoved")
      )
    }
  }

  @ViewBuilder
  private func limitOptionLabel(policy: SeriesOfflinePolicy, limit: Int) -> some View {
    let title = SeriesOfflinePolicy.limitTitle(limit)
    if offlinePolicy == policy && offlinePolicyLimit == limit {
      Label(title, systemImage: "checkmark")
    } else {
      Text(title)
    }
  }

}
