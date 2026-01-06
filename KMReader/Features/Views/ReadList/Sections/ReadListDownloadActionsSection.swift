//
//  ReadListDownloadActionsSection.swift
//  KMReader
//

import SwiftData
import SwiftUI

struct ReadListDownloadActionsSection: View {
  @Bindable var komgaReadList: KomgaReadList

  @AppStorage("currentInstanceId") private var currentInstanceId: String = ""

  private var readList: ReadList {
    komgaReadList.toReadList()
  }

  private var status: SeriesDownloadStatus {
    komgaReadList.downloadStatus
  }

  @State private var pendingAction: SeriesDownloadAction?

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

        let actions = SeriesDownloadAction.availableActions(for: status)
        if actions.count > 1 {
          Menu {
            actionsView(actions: actions)
          } label: {
            statusButtonLabel
          }
          .font(.caption)
          .adaptiveButtonStyle(status.isProminent ? .borderedProminent : .bordered)
          .tint(status.menuColor)
        } else if let action = actions.first {
          Button(role: action.isDestructive ? .destructive : .none) {
            handleActionTap(action)
          } label: {
            statusButtonLabel
          }
          .font(.caption)
          .adaptiveButtonStyle(status.isProminent ? .borderedProminent : .bordered)
          .tint(status.menuColor)
        }
      }
    }
    .animation(.easeInOut(duration: 0.2), value: status)
    .padding(.vertical, 4)
    .alert(
      pendingAction?.label(for: status) ?? "",
      isPresented: Binding(
        get: { pendingAction != nil },
        set: { if !$0 { pendingAction = nil } }
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
  private var statusButtonLabel: some View {
    Label {
      Text(status.menuLabel)
    } icon: {
      Image(systemName: status.menuIcon)
        .frame(width: PlatformHelper.iconSize, height: PlatformHelper.iconSize)
    }
  }

  @ViewBuilder
  private func actionsView(actions: [SeriesDownloadAction]) -> some View {
    ForEach(actions) { action in
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

  private func performAction(_ action: SeriesDownloadAction) {
    switch action {
    case .download:
      downloadAll()
    case .remove, .cancel:
      removeAll()
    }
  }

  private func downloadAll() {
    Task {
      // Sync books first
      try? await SyncService.shared.syncAllReadListBooks(readListId: readList.id)
      await DatabaseOperator.shared.downloadReadListOffline(
        readListId: readList.id, instanceId: currentInstanceId
      )
      await DatabaseOperator.shared.commit()
      await MainActor.run {
        ErrorManager.shared.notify(
          message: String(localized: "notification.readList.offlineDownloadQueued")
        )
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
      }
    }
  }
}
