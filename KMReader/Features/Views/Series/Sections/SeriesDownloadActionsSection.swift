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

  private var policyLabel: Text {
    Text("Offline Policy") + Text(" : ") + Text(policy.label)
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

        Menu {
          Picker(
            "",
            selection: Binding(
              get: { policy },
              set: { updatePolicy($0) }
            )
          ) {
            ForEach(SeriesOfflinePolicy.allCases, id: \.self) { p in
              Label(p.label, systemImage: p.icon)
                .tag(p)
            }
          }
          .pickerStyle(.inline)
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
    .animation(.easeInOut(duration: 0.2), value: policy)
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

  private func updatePolicy(_ newPolicy: SeriesOfflinePolicy) {
    Task {
      await DatabaseOperator.shared.updateSeriesOfflinePolicy(
        seriesId: series.id, instanceId: currentInstanceId, policy: newPolicy
      )
      try? await DatabaseOperator.shared.commit()
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
      await DatabaseOperator.shared.downloadSeriesOffline(
        seriesId: series.id, instanceId: currentInstanceId
      )
      try? await DatabaseOperator.shared.commit()
    }
  }

  private func removeAll() {
    Task {
      await DatabaseOperator.shared.removeSeriesOffline(
        seriesId: series.id, instanceId: currentInstanceId
      )
      try? await DatabaseOperator.shared.commit()
    }
  }
}
