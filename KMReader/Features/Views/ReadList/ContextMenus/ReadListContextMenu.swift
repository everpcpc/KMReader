//
//  ReadListContextMenu.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

@MainActor
struct ReadListContextMenu: View {
  @Bindable var komgaReadList: KomgaReadList

  var onActionCompleted: (() -> Void)? = nil
  var onDeleteRequested: (() -> Void)? = nil
  var onEditRequested: (() -> Void)? = nil

  @AppStorage("isAdmin") private var isAdmin: Bool = false
  @AppStorage("currentInstanceId") private var currentInstanceId: String = ""
  @AppStorage("isOffline") private var isOffline: Bool = false

  private var readList: ReadList {
    komgaReadList.toReadList()
  }

  private var status: SeriesDownloadStatus {
    komgaReadList.downloadStatus
  }

  private var limitPresets: [Int] {
    [1, 3, 5, 10, 25, 50, 0]
  }

  var body: some View {
    Group {
      NavigationLink(value: NavDestination.readListDetail(readListId: readList.id)) {
        Label("View Details", systemImage: "info.circle")
      }

      if !isOffline {
        Divider()

        Menu {
          actionsView(actions: SeriesDownloadAction.availableActions(for: status))
        } label: {
          Label("Offline", systemImage: status.icon)
        }

        if isAdmin {
          Divider()
          Button {
            onEditRequested?()
          } label: {
            Label("Edit", systemImage: "pencil")
          }
          Divider()
          Button(role: .destructive) {
            onDeleteRequested?()
          } label: {
            Label("Delete", systemImage: "trash")
          }
        }
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
      try? await SyncService.shared.syncAllReadListBooks(readListId: readList.id)
      await DatabaseOperator.shared.downloadReadListOffline(
        readListId: readList.id, instanceId: currentInstanceId
      )
      await DatabaseOperator.shared.commit()
      await MainActor.run {
        ErrorManager.shared.notify(
          message: String(localized: "notification.readList.offlineDownloadQueued")
        )
        onActionCompleted?()
      }
    }
  }

  private func downloadUnread(limit: Int) {
    Task {
      try? await SyncService.shared.syncAllReadListBooks(readListId: readList.id)
      await DatabaseOperator.shared.downloadReadListUnreadOffline(
        readListId: readList.id,
        instanceId: currentInstanceId,
        limit: limit
      )
      await DatabaseOperator.shared.commit()
      await MainActor.run {
        ErrorManager.shared.notify(
          message: String(localized: "notification.readList.offlineDownloadQueued")
        )
        onActionCompleted?()
      }
    }
  }

  private func removeRead() {
    Task {
      await DatabaseOperator.shared.removeReadListReadOffline(
        readListId: readList.id,
        instanceId: currentInstanceId
      )
      await DatabaseOperator.shared.commit()
      await MainActor.run {
        ErrorManager.shared.notify(
          message: String(localized: "notification.readList.offlineRemoved")
        )
        onActionCompleted?()
      }
    }
  }

  private func removeAll() {
    Task {
      await DatabaseOperator.shared.removeReadListOffline(
        readListId: readList.id, instanceId: currentInstanceId
      )
      await DatabaseOperator.shared.commit()
      await MainActor.run {
        ErrorManager.shared.notify(
          message: String(localized: "notification.readList.offlineRemoved")
        )
        onActionCompleted?()
      }
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
