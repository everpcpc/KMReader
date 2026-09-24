//
// DetailTimestampsView.swift
//
//

import SwiftUI

/// Created/modified dates as a quiet caption row, kept out of chip
/// chrome so detail pages don't accumulate visual noise.
struct DetailTimestampsView: View {
  let created: Date
  let lastModified: Date

  var body: some View {
    HStack(spacing: 12) {
      Label(
        "Created: \(created.formattedMediumDate)",
        systemImage: "calendar.badge.plus"
      )
      Label(
        "Modified: \(lastModified.formattedMediumDate)",
        systemImage: "clock"
      )
    }
    .font(.caption)
    .foregroundStyle(.secondary)
  }
}
