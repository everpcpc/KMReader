//
//  DeletedBadge.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct DeletedBadge: View {
  var body: some View {
    Label("Deleted", systemImage: "trash.fill")
      .font(.caption2.weight(.semibold))
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .foregroundColor(.white)
      .background(Color.red.opacity(0.9))
      .clipShape(Capsule())
      .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
  }
}

#Preview {
  DeletedBadge()
    .padding()
}
