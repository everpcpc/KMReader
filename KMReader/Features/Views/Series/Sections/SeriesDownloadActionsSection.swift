//
//  SeriesDownloadActionsSection.swift
//  KMReader
//

import SwiftData
import SwiftUI

struct SeriesDownloadActionsSection: View {
  @Bindable var komgaSeries: KomgaSeries

  @AppStorage("currentInstanceId") private var currentInstanceId: String = ""

  private var series: Series {
    komgaSeries.toSeries()
  }

  private var status: SeriesDownloadStatus {
    komgaSeries.downloadStatus
  }

  private var policy: SeriesOfflinePolicy {
    komgaSeries.offlinePolicy
  }

  private var limitPresets: [Int] {
    [1, 3, 5, 10, 25, 50, 0]
  }

  private var policyLabel: Text {
    Text("Offline Policy") + Text(" : ") + Text(policy.title(limit: komgaSeries.offlinePolicyLimit))
  }

  private var actions: [SeriesDownloadAction] {
    SeriesDownloadAction.availableActions(for: status)
  }

  @State private var pendingAction: SeriesDownloadAction?
  @State private var pendingUnreadLimit: Int?

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
          Label {
            policyLabel.lineLimit(1)
          } icon: {
            Image(systemName: policy.icon)
              .frame(width: PlatformHelper.iconSize, height: PlatformHelper.iconSize)
          }
        }
        .font(.caption)
        .adaptiveButtonStyle(.bordered)

        Menu {
          actionsView(actions: actions)
        } label: {
          statusButtonLabel
        }
        .font(.caption)
        .adaptiveButtonStyle(status.isProminent ? .borderedProminent : .bordered)
      }
    }
    .animation(.easeInOut(duration: 0.2), value: status)
    .animation(.easeInOut(duration: 0.2), value: policy)
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
  private var statusButtonLabel: some View {
    Label {
      Text(String(localized: "Download"))
    } icon: {
      Image(systemName: status.menuIcon)
        .frame(width: PlatformHelper.iconSize, height: PlatformHelper.iconSize)
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

  private func updatePolicy(_ newPolicy: SeriesOfflinePolicy) {
    Task {
      // Sync books first if policy is not manual
      if newPolicy != .manual {
        try? await SyncService.shared.syncAllSeriesBooks(seriesId: series.id)
      }
      await DatabaseOperator.shared.updateSeriesOfflinePolicy(
        seriesId: series.id, instanceId: currentInstanceId, policy: newPolicy
      )
      await DatabaseOperator.shared.commit()
    }
  }

  private func updatePolicyAndLimit(_ newPolicy: SeriesOfflinePolicy, limit: Int) {
    Task {
      try? await SyncService.shared.syncAllSeriesBooks(seriesId: series.id)
      await DatabaseOperator.shared.updateSeriesOfflinePolicy(
        seriesId: series.id,
        instanceId: currentInstanceId,
        policy: newPolicy,
        limit: limit
      )
      await DatabaseOperator.shared.commit()
    }
  }

  @ViewBuilder
  private func offlinePolicyLabel(_ value: SeriesOfflinePolicy) -> some View {
    let title = value.title(limit: komgaSeries.offlinePolicyLimit)
    if value == policy {
      Label(title, systemImage: "checkmark")
    } else {
      Label(value.label, systemImage: value.icon)
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

  private func performAction(_ action: SeriesDownloadAction) {
    switch action {
    case .download:
      downloadAll()
    case .downloadUnread:
      let limit = pendingUnreadLimit ?? komgaSeries.offlinePolicyLimit
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
      try? await SyncService.shared.syncAllSeriesBooks(seriesId: series.id)
      await DatabaseOperator.shared.downloadSeriesOffline(
        seriesId: series.id, instanceId: currentInstanceId
      )
      await DatabaseOperator.shared.commit()
      await MainActor.run {
        ErrorManager.shared.notify(
          message: String(localized: "notification.series.offlineDownloadQueued")
        )
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
      }
    }
  }

  private func removeRead() {
    Task {
      await DatabaseOperator.shared.removeSeriesReadOffline(
        seriesId: series.id,
        instanceId: currentInstanceId
      )
      await DatabaseOperator.shared.commit()
      await MainActor.run {
        ErrorManager.shared.notify(
          message: String(localized: "notification.series.offlineRemoved")
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
      await DatabaseOperator.shared.removeSeriesOffline(
        seriesId: series.id, instanceId: currentInstanceId
      )
      await DatabaseOperator.shared.commit()
      await MainActor.run {
        ErrorManager.shared.notify(
          message: String(localized: "notification.series.offlineRemoved")
        )
      }
    }
  }
}
