//
// DownloadStatusIcon.swift
//
//

import SwiftUI

struct DownloadStatusIcon: View {
  let systemName: String
  let spinning: Bool

  var body: some View {
    if #available(iOS 18.0, macOS 15.0, tvOS 18.0, *) {
      Image(systemName: systemName)
        .symbolEffect(.rotate, isActive: spinning)
        .foregroundColor(.secondary)
    } else if spinning {
      // Older OSes get a real spinner: symbolEffect(.rotate) is iOS 18+.
      ProgressView()
        .controlSize(.mini)
        .tint(.secondary)
    } else {
      Image(systemName: systemName)
        .foregroundColor(.secondary)
    }
  }
}
