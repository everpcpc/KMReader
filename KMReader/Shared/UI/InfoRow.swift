//
//  InfoRow.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct InfoRow: View {
  let label: String
  let value: String
  let icon: String

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Label {
        Text(label)
          .font(.caption)
          .fontWeight(.semibold)
          .foregroundColor(.secondary)
      } icon: {
        Image(systemName: icon)
          .font(.caption)
          .foregroundColor(.secondary)
          .frame(width: 16)
      }

      Spacer()

      Text(value)
        .font(.caption)
        .foregroundColor(.primary)
        .multilineTextAlignment(.trailing)
        .lineLimit(2)
    }
  }
}
