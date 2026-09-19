//
// DownloadStatusIcon.swift
//
//

import SwiftUI

struct DownloadStatusIcon: View {
  let systemName: String
  let spinning: Bool
  var color: Color = .secondary

  var body: some View {
    Group {
      if spinning {
        spinningContent
          .transition(.opacity)
      } else {
        Image(systemName: systemName)
          .foregroundColor(color)
          .transition(.opacity)
      }
    }
    .animation(.default, value: spinning)
  }

  @ViewBuilder
  private var spinningContent: some View {
    if #available(iOS 18.0, macOS 15.0, tvOS 18.0, *) {
      Image(systemName: systemName)
        .symbolEffect(.rotate)
        .foregroundColor(color)
    } else {
      // Older OSes get a real spinner: symbolEffect(.rotate) is iOS 18+.
      ProgressView()
        .controlSize(.mini)
        .tint(color)
    }
  }
}
