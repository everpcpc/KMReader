//
//  ReadListDownloadActionsSection.swift
//  KMReader
//

import SwiftData
import SwiftUI

struct ReadListDownloadActionsSection: View {
  @Bindable var komgaReadList: KomgaReadList

  @AppStorage("currentAccount") private var current: Current = .init()

  private var readList: ReadList {
    komgaReadList.toReadList()
  }

  private var status: SeriesDownloadStatus {
    komgaReadList.downloadStatus
  }

  @State private var pendingAction: SeriesDownloadAction?
  @State private var pendingUnreadLimit: Int?

  private var limitPresets: [Int] {
    [1, 3, 5, 10, 25, 50, 0]
  }

  private var actions: [SeriesDownloadAction] {
    SeriesDownloadAction.availableActions(for: status)
  }

  var body: some View {
    VStack(spacing: 12) {
      HStack(spacing: 12) {
        InfoChip(
          label: status.label,
          systemImage: status.icon,
          backgroundColor: status.color.opacity(0.2),
          foregroundColor: status.color
        )

        Spacer()

        Menu {
          actionsView(actions: actions)
        } label: {
          Text(String(localized: "Download"))
        }
        .font(.caption)
        .adaptiveButtonStyle(status.isProminent ? .borderedProminent : .bordered)
      }
    }
    .animation(.easeInOut(duration: 0.2), value: status)
    .padding(.vertical, 4)
    .alert(
      pendingAction?.label(for: status) ?? "",
      isPresented: Binding(
        get: { pendingAction != nil },
        set: {
          if !$0 {
            pendingAction = nil
            pendingUnreadLimit = nil
          }
        }
      ),
      presenting: pendingAction
    ) { action in
      Button(action.label(for: status), role: action.isDestructive ? .destructive : .none) {
        performAction(action)
      }
      Button(String(localized: "Cancel"), role: .cancel) {}
    } message: { action in
      let message = action.confirmationMessage(for: status)
      if !message.isEmpty {
        Text(message)
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
    if action.requiresConfirmation {
      pendingAction = action
    } else {
      performAction(action)
    }
  }

  private func handleDownloadUnreadTap(limit: Int) {
    if SeriesDownloadAction.downloadUnread.requiresConfirmation {
      pendingUnreadLimit = limit
      pendingAction = .downloadUnread
    } else {
      downloadUnread(limit: limit)
    }
  }

  private func performAction(_ action: SeriesDownloadAction) {
    switch action {
    case .download:
      downloadAll()
    case .downloadUnread:
      let limit = pendingUnreadLimit ?? 0
      pendingUnreadLimit = nil
      downloadUnread(limit: limit)
    case .removeRead:
      removeRead()
    case .remove, .cancel:
      removeAll()
    }
  }

  private func downloadAll() {
    Task {
      // Sync books first
      try? await SyncService.shared.syncAllReadListBooks(readListId: readList.id)
      await DatabaseOperator.shared.downloadReadListOffline(
        readListId: readList.id, instanceId: current.instanceId
      )
      await DatabaseOperator.shared.commit()
      await MainActor.run {
        ErrorManager.shared.notify(
          message: String(localized: "notification.readList.offlineDownloadQueued")
        )
      }
    }
  }

  private func downloadUnread(limit: Int) {
    Task {
      try? await SyncService.shared.syncAllReadListBooks(readListId: readList.id)
      await DatabaseOperator.shared.downloadReadListUnreadOffline(
        readListId: readList.id,
        instanceId: current.instanceId,
        limit: limit
      )
      await DatabaseOperator.shared.commit()
      await MainActor.run {
        ErrorManager.shared.notify(
          message: String(localized: "notification.readList.offlineDownloadQueued")
        )
      }
    }
  }

  private func removeRead() {
    Task {
      await DatabaseOperator.shared.removeReadListReadOffline(
        readListId: readList.id,
        instanceId: current.instanceId
      )
      await DatabaseOperator.shared.commit()
      await MainActor.run {
        ErrorManager.shared.notify(
          message: String(localized: "notification.readList.offlineRemoved")
        )
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

  private func removeAll() {
    Task {
      await DatabaseOperator.shared.removeReadListOffline(
        readListId: readList.id, instanceId: current.instanceId
      )
      await DatabaseOperator.shared.commit()
      await MainActor.run {
        ErrorManager.shared.notify(
          message: String(localized: "notification.readList.offlineRemoved")
        )
      }
    }
  }
}
