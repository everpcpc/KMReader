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
      // ProgressView instead of symbolEffect(.rotate), which requires iOS 18.
      ProgressView()
        .controlSize(.mini)
        .tint(.secondary)
    } else {
      Image(systemName: systemName)
        .foregroundColor(.secondary)
    }
  }
}
