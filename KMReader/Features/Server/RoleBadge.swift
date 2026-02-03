//
//  RoleBadge.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftUI

struct RoleBadge: View {
  let role: UserRole

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: role.icon)
        .font(.caption2)
      Text(role.displayName)
        .font(.caption)
        .fontWeight(.medium)
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(Color.accentColor.opacity(0.15))
    .foregroundColor(.accentColor)
    .clipShape(Capsule())
  }
}
