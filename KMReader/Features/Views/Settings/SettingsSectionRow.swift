//
//  SettingsSectionRow.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct SettingsSectionRow: View {
  let section: SettingsSection
  var subtitle: String? = nil
  var badge: String? = nil
  var badgeColor: Color? = nil

  var body: some View {
    HStack {
      Label(section.title, systemImage: section.icon)
      Spacer()
      if let subtitle {
        Text(subtitle)
          .foregroundColor(.secondary)
          .lineLimit(1)
      }
      if let badge {
        HStack(spacing: 4) {
          if let badgeColor {
            Circle()
              .fill(badgeColor)
              .frame(width: 8, height: 8)
          }
          Text(badge)
            .font(.caption)
            .foregroundColor(badgeColor ?? .secondary)
            .fontWeight(.semibold)
        }
      }
    }
    .tag(section)
  }
}
