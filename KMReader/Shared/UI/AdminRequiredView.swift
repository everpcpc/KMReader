//
//  AdminRequiredView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct AdminRequiredView: View {
  var body: some View {
    Section {
      HStack {
        Spacer()
        VStack(spacing: 8) {
          Image(systemName: "lock.shield")
            .font(.system(size: 40))
            .foregroundColor(.secondary)
          Text("Admin access required")
            .font(.headline)
            .foregroundColor(.secondary)
          Text("This feature is only available to administrators")
            .font(.caption)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
        }
        Spacer()
      }
      .padding(.vertical)
      .tvFocusableHighlight()
    }
  }
}
