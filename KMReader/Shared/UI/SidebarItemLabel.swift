//
//  SidebarItemLabel.swift
//  KMReader
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
          .foregroundColor(.secondary)
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(Color.secondary.opacity(0.1))
          .clipShape(Capsule())
      }
    }
  }
}
