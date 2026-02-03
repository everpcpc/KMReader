//
//  OfflineTasksStatusView.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftUI

struct OfflineTasksStatusView: View {
  @AppStorage("offlinePaused") private var offlinePaused: Bool = false
  @AppStorage("currentAccount") private var current: Current = .init()

  @State private var summary: DownloadQueueSummary = .empty
  @State private var progressTracker = DownloadProgressTracker.shared

  var body: some View {
    HStack(spacing: 6) {
      if offlinePaused {
        statusBadge(
          title: SyncStatus.paused.label,
          systemImage: SyncStatus.paused.icon,
          color: SyncStatus.paused.color
        )
      } else if summary.isEmpty {
        statusBadge(
          title: SyncStatus.idle.label,
          systemImage: SyncStatus.idle.icon,
          color: SyncStatus.idle.color
        )
      } else {

        if summary.downloadingCount > 0 {
          statusBadge(
            title: "\(summary.downloadingCount)",
            systemImage: "arrow.down.circle.fill",
            color: Color.accentColor
          )
        }
        if summary.pendingCount > 0 {
          statusBadge(
            title: "\(summary.pendingCount)",
            systemImage: "clock.fill",
            color: .secondary
          )
        }
        if summary.failedCount > 0 {
          statusBadge(
            title: "\(summary.failedCount)",
            systemImage: "exclamationmark.circle.fill",
            color: .red
          )
        }
      }
    }
    .task(id: current.instanceId) {
      await loadSummary()
    }
    .onChange(of: progressTracker.pendingCount) { _, _ in
      Task { await loadSummary() }
    }
    .onChange(of: progressTracker.failedCount) { _, _ in
      Task { await loadSummary() }
    }
    .onChange(of: progressTracker.currentBookName) { _, _ in
      Task { await loadSummary() }
    }
  }

  @ViewBuilder
  private func statusBadge(title: String, systemImage: String, color: Color) -> some View {
    HStack(spacing: 4) {
      Image(systemName: systemImage)
        .font(.caption2)
      Text(title)
        .font(.caption2)
        .fontWeight(.semibold)
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(color.opacity(0.15), in: Capsule())
    .foregroundColor(color)
  }

  @MainActor
  private func loadSummary() async {
    let instanceId = current.instanceId
    guard !instanceId.isEmpty else {
      summary = .empty
      return
    }
    summary = await DatabaseOperator.shared.fetchDownloadQueueSummary(instanceId: instanceId)
  }
}
