//
//  OfflineShortcutRow.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftUI

struct OfflineShortcutRow<Accessory: View>: View {
  let title: String
  let subtitle: String?
  let systemImage: String
  let accessory: Accessory

  init(
    title: String,
    subtitle: String? = nil,
    systemImage: String,
    @ViewBuilder accessory: () -> Accessory
  ) {
    self.title = title
    self.subtitle = subtitle
    self.systemImage = systemImage
    self.accessory = accessory()
  }

  init(
    title: String,
    subtitle: String? = nil,
    systemImage: String
  ) where Accessory == EmptyView {
    self.title = title
    self.subtitle = subtitle
    self.systemImage = systemImage
    self.accessory = EmptyView()
  }

  var body: some View {
    HStack(spacing: 12) {
      ZStack {
        RoundedRectangle(cornerRadius: 10)
          .fill(Color.accentColor.opacity(0.15))
        Image(systemName: systemImage)
          .foregroundColor(Color.accentColor)
      }
      .frame(width: 36, height: 36)

      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.headline)
        if let subtitle {
          Text(subtitle)
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }

      Spacer()

      accessory

      Image(systemName: "chevron.right")
        .font(.caption)
        .foregroundColor(.secondary)
    }
    .padding(12)
    .background(.thinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }
}
