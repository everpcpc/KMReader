//
// SidebarItemLabel.swift
//
//

import SwiftUI

struct SidebarItemLabel: View {
  let title: String
  let count: Int?

  var body: some View {
    HStack {
      Text(title).lineLimit(1)
      Spacer()
      if let count {
        Text("\(count)")
          .font(.caption2)
          // Hierarchical styles derive from the row's actual foreground, so
          // the badge stays readable on the inverted selected-row pill.
          .foregroundStyle(.secondary)
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(.secondary.opacity(0.1), in: Capsule())
      }
    }
  }
}
