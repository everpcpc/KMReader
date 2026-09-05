//
// SettingsBadgeRow.swift
//
//

import SwiftUI

/// Settings entry row with an Apple Settings-style colored icon badge.
struct SettingsBadgeRow: View {
  let title: String
  let icon: String
  let color: Color
  var subtitle: String? = nil
  var badge: String? = nil
  var badgeColor: Color? = nil

  var body: some View {
    HStack {
      Label {
        Text(title)
      } icon: {
        Image(systemName: icon)
          .font(.footnote)
          .fontWeight(.semibold)
          .foregroundStyle(.white)
          .frame(width: 29, height: 29)
          .background(color, in: RoundedRectangle(cornerRadius: 6.5, style: .continuous))
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
  }
}
