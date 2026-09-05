//
// SettingsSectionRow.swift
//
//

import SwiftUI

struct SettingsSectionRow: View {
  let section: SettingsSection
  var icon: String? = nil
  var subtitle: String? = nil
  var badge: String? = nil
  var badgeColor: Color? = nil

  var body: some View {
    HStack {
      Label {
        Text(section.title)
      } icon: {
        Image(systemName: icon ?? section.icon)
          .font(.footnote)
          .fontWeight(.semibold)
          .foregroundStyle(.white)
          .frame(width: 29, height: 29)
          .background(section.color, in: RoundedRectangle(cornerRadius: 6.5, style: .continuous))
      }
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
