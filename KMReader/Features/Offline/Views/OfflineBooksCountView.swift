//
//  OfflineBooksCountView.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftUI

struct OfflineBooksCountView: View {
  @AppStorage("currentAccount") private var current: Current = .init()

  @State private var downloadedCount: Int = 0
  @State private var progressTracker = DownloadProgressTracker.shared

  var body: some View {
    Group {
      if downloadedCount > 0 {
        Text("\(downloadedCount)")
          .font(.caption2)
          .fontWeight(.semibold)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(Color.accentColor.opacity(0.15), in: Capsule())
          .foregroundColor(Color.accentColor)
      } else {
        Text("")
      }
    }
    .task(id: current.instanceId) {
      await loadCount()
    }
    .onChange(of: progressTracker.pendingCount) { _, _ in
      Task { await loadCount() }
    }
    .onChange(of: progressTracker.failedCount) { _, _ in
      Task { await loadCount() }
    }
    .onChange(of: progressTracker.currentBookName) { _, _ in
      Task { await loadCount() }
    }
  }

  private func loadCount() async {
    let instanceId = current.instanceId
    guard !instanceId.isEmpty else {
      downloadedCount = 0
      return
    }
    let count = await DatabaseOperator.shared.fetchDownloadedBooksCount(instanceId: instanceId)
    downloadedCount = count
  }
}
