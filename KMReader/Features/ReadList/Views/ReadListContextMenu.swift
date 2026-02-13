//
//  ReadListContextMenu.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct ReadListContextMenu: View {
  let readListId: String
  let menuTitle: String
  let downloadStatus: SeriesDownloadStatus

  var onDeleteRequested: (() -> Void)? = nil
  var onEditRequested: (() -> Void)? = nil

  @AppStorage("currentAccount") private var current: Current = .init()
  @AppStorage("isOffline") private var isOffline: Bool = false

  private var status: SeriesDownloadStatus {
    downloadStatus
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

      NavigationLink(value: NavDestination.readListDetail(readListId: readListId)) {
        Label("View Details", systemImage: "info.circle")
      }

      if !isOffline {
        Divider()
        Menu {
          actionsView(actions: SeriesDownloadAction.availableActions(for: status))
        } label: {
          Label("Offline", systemImage: status.icon)
        }

        if current.isAdmin {
          Divider()
          Button {
            onEditRequested?()
          } label: {
            Label("Edit", systemImage: "pencil")
          }
        }

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
        try await ThumbnailCache.refreshThumbnail(id: readListId, type: .readlist)
        ErrorManager.shared.notify(message: String(localized: "notification.readList.coverRefreshed"))
      } catch {
        ErrorManager.shared.alert(error: error)
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

  private func performAction(_ action: SeriesDownloadAction) {
    switch action {
    case .download:
      downloadAll()
    case .downloadUnread:
      downloadUnread(limit: 0)
    case .removeRead:
      removeRead()
    case .remove, .cancel:
      removeAll()
    }
  }

  private func downloadAll() {
    Task {
      try? await SyncService.shared.syncAllReadListBooks(readListId: readListId)
      await DatabaseOperator.shared.downloadReadListOffline(
        readListId: readListId, instanceId: current.instanceId
      )
      await DatabaseOperator.shared.commit()
      ErrorManager.shared.notify(
        message: String(localized: "notification.readList.offlineDownloadQueued")
      )
    }
  }

  private func downloadUnread(limit: Int) {
    Task {
      try? await SyncService.shared.syncAllReadListBooks(readListId: readListId)
      await DatabaseOperator.shared.downloadReadListUnreadOffline(
        readListId: readListId,
        instanceId: current.instanceId,
        limit: limit
      )
      await DatabaseOperator.shared.commit()
      ErrorManager.shared.notify(
        message: String(localized: "notification.readList.offlineDownloadQueued")
      )
    }
  }

  private func removeRead() {
    Task {
      await DatabaseOperator.shared.removeReadListReadOffline(
        readListId: readListId,
        instanceId: current.instanceId
      )
      await DatabaseOperator.shared.commit()
      ErrorManager.shared.notify(
        message: String(localized: "notification.readList.offlineRemoved")
      )
    }
  }

  private func removeAll() {
    Task {
      await DatabaseOperator.shared.removeReadListOffline(
        readListId: readListId, instanceId: current.instanceId
      )
      await DatabaseOperator.shared.commit()
      ErrorManager.shared.notify(
        message: String(localized: "notification.readList.offlineRemoved")
      )
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
}
