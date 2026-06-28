//
// OfflineCoverSyncProgressView.swift
//
//

import SwiftUI

struct OfflineCoverSyncProgressView: View {
  let progress: OfflineCoverSyncProgress

  var body: some View {
    HStack(spacing: 8) {
      ProgressView(value: progress.progressFraction)
        .frame(width: 56)
        .animation(.easeInOut(duration: 0.2), value: progress.progressFraction)
      Text(
        String(
          localized:
            "offline.coverSync.progressChecked \(progress.checkedCount) \(progress.totalCount)"
        )
      )
      .contentTransition(.numericText())
      .animation(.default, value: progress.checkedCount)
      .animation(.default, value: progress.totalCount)
      Text(String(localized: "offline.coverSync.progressSynced \(progress.storedCount)"))
        .contentTransition(.numericText())
        .animation(.default, value: progress.storedCount)
      if progress.failedCount > 0 {
        Text(String(localized: "offline.coverSync.progressFailed \(progress.failedCount)"))
          .contentTransition(.numericText())
          .animation(.default, value: progress.failedCount)
      }
    }
    .font(.caption2)
    .foregroundStyle(.secondary)
    .lineLimit(1)
    .monospacedDigit()
  }
}
