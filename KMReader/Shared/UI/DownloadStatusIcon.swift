//
// DownloadStatusIcon.swift
//
//

import SwiftUI

struct DownloadStatusIcon: View {
  let systemName: String
  let spinning: Bool

  var body: some View {
    if spinning {
      spinningContent
    } else {
      Image(systemName: systemName)
        .foregroundColor(.secondary)
    }
  }

  @ViewBuilder
  private var spinningContent: some View {
    if #available(iOS 18.0, macOS 15.0, tvOS 18.0, *) {
      Image(systemName: systemName)
        .symbolEffect(.rotate)
        .foregroundColor(.secondary)
    } else {
      // Older OSes get a real spinner: symbolEffect(.rotate) is iOS 18+.
      ProgressView()
        .controlSize(.mini)
        .tint(.secondary)
    }
  }
}
