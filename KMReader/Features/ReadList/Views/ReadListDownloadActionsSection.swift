//
// ReadListDownloadActionsSection.swift
//
//

import SwiftUI

struct ReadListDownloadActionsSection: View {
  let readListId: String
  let status: SeriesDownloadStatus
  let policy: OfflinePolicy
  let offlinePolicyLimit: Int
  var onMutationCompleted: (() -> Void)? = nil

  @AppStorage("currentAccount") private var current: Current = .init()

  @State private var pendingAction: SeriesDownloadAction?
  @State private var pendingUnreadLimit: Int?

  private var limitPresets: [Int] {
    [1, 3, 5, 10, 25, 50, 0]
  }

  private var actions: [SeriesDownloadAction] {
    SeriesDownloadAction.availableReadListActions(for: status)
  }

  private var policyLabel: Text {
    Text("Offline Policy") + Text(" : ") + Text(policy.title(limit: offlinePolicyLimit))
  }

  var body: some View {
    VStack(spacing: 12) {
      HStack(spacing: 12) {
        Menu {
          actionsView(actions: actions)
        } label: {
          HStack(spacing: 4) {
            Text(String(localized: "Download"))
            Image(systemName: "chevron.down")
          }
        }
        .font(.caption)
        .adaptiveButtonStyle(.bordered)

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

          Button {
            updatePolicy(.all)
          } label: {
            offlinePolicyLabel(.all)
          }
        } label: {
          HStack(spacing: 4) {
            Image(systemName: policy.icon)
            policyLabel.lineLimit(1)
            Image(systemName: "chevron.down")
          }
        }
        .font(.caption)
        .adaptiveButtonStyle(.bordered)

        Spacer()

        InfoChip(
          label: status.label,
          systemImage: status.icon,
          backgroundColor: status.color.opacity(0.2),
          foregroundColor: status.color
        )
      }
    }
    .padding(.vertical, 4)
    .animation(.default, value: status)
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

  private func updatePolicy(_ newPolicy: OfflinePolicy) {
    Task {
      if newPolicy != .manual {
        try? await SyncService.syncAllReadListBooks(readListId: readListId)
      }
      try? await DatabaseOperator.database().updateReadListOfflinePolicy(
        readListId: readListId,
        instanceId: current.instanceId,
        policy: newPolicy
      )
      onMutationCompleted?()
    }
  }

  private func updatePolicyAndLimit(_ newPolicy: OfflinePolicy, limit: Int) {
    Task {
      try? await SyncService.syncAllReadListBooks(readListId: readListId)
      try? await DatabaseOperator.database().updateReadListOfflinePolicy(
        readListId: readListId,
        instanceId: current.instanceId,
        policy: newPolicy,
        limit: limit
      )
      onMutationCompleted?()
    }
  }

  @ViewBuilder
  private func offlinePolicyLabel(_ value: OfflinePolicy) -> some View {
    let title = value.title(limit: offlinePolicyLimit)
    Label {
      HStack(spacing: 4) {
        Text(value == policy ? title : value.label)
        if value == policy {
          Image(systemName: "checkmark")
        }
      }
    } icon: {
      Image(systemName: value.icon)
    }
  }

  @ViewBuilder
  private func limitOptionLabel(policy: OfflinePolicy, limit: Int) -> some View {
    let title = OfflinePolicy.limitTitle(limit)
    if self.policy == policy && offlinePolicyLimit == limit {
      Label(title, systemImage: "checkmark")
    } else {
      Text(title)
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
    case .remove:
      removeAll()
    case .cancel:
      cancelDownload()
    }
  }

  private func downloadAll() {
    Task {
      // Sync books first
      try? await SyncService.syncAllReadListBooks(readListId: readListId)
      try? await DatabaseOperator.database().downloadReadListOffline(
        readListId: readListId, instanceId: current.instanceId
      )
      ErrorManager.shared.notify(
        message: String(localized: "notification.readList.offlineDownloadQueued")
      )
      onMutationCompleted?()
    }
  }

  private func downloadUnread(limit: Int) {
    Task {
      try? await SyncService.syncAllReadListBooks(readListId: readListId)
      try? await DatabaseOperator.database().downloadReadListUnreadOffline(
        readListId: readListId,
        instanceId: current.instanceId,
        limit: limit
      )
      ErrorManager.shared.notify(
        message: String(localized: "notification.readList.offlineDownloadQueued")
      )
      onMutationCompleted?()
    }
  }

  private func removeRead() {
    Task {
      try? await DatabaseOperator.database().removeReadListReadOffline(
        readListId: readListId,
        instanceId: current.instanceId
      )
      ErrorManager.shared.notify(
        message: String(localized: "notification.readList.offlineRemoved")
      )
      onMutationCompleted?()
    }
  }

  @ViewBuilder
  private func downloadUnreadLimitOptions() -> some View {
    ForEach(limitPresets, id: \.self) { value in
      Button {
        handleDownloadUnreadTap(limit: value)
      } label: {
        Text(OfflinePolicy.limitTitle(value))
      }
    }
  }

  private func removeAll() {
    Task {
      try? await DatabaseOperator.database().removeReadListOffline(
        readListId: readListId, instanceId: current.instanceId
      )
      ErrorManager.shared.notify(
        message: String(localized: "notification.readList.offlineRemoved")
      )
      onMutationCompleted?()
    }
  }

  private func cancelDownload() {
    Task {
      await OfflineManager.shared.cancelReadListDownload(
        readListId: readListId,
        instanceId: current.instanceId
      )
      ErrorManager.shared.notify(
        message: String(localized: "notification.book.downloadCancelled", defaultValue: "Download cancelled")
      )
      onMutationCompleted?()
    }
  }
}
