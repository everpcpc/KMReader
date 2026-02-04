//
//  ServerActionTile.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftUI

struct ServerActionTile: View {
  let title: String
  let systemImage: String
  var subtitle: String? = nil
  var badge: String? = nil
  var badgeColor: Color? = nil

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 8) {
        ZStack {
          RoundedRectangle(cornerRadius: 10)
            .fill(Color.accentColor.opacity(0.15))
          Image(systemName: systemImage)
            .foregroundColor(Color.accentColor)
        }
        .frame(width: 34, height: 34)

        Spacer()

        HStack(spacing: 6) {
          if let badge {
            Text(badge)
              .font(.caption2)
              .fontWeight(.semibold)
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background((badgeColor ?? .secondary).opacity(0.15), in: Capsule())
              .foregroundColor(badgeColor ?? .secondary)
          }

          Image(systemName: "chevron.right")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }

      Text(title)
        .font(.headline)
        .lineLimit(1)
        .truncationMode(.tail)

      if let subtitle {
        Text(subtitle)
          .font(.caption)
          .foregroundColor(.secondary)
          .lineLimit(2)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(.thinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 14))
  }
}
