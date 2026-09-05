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
    SettingsBadgeRow(
      title: section.title,
      icon: icon ?? section.icon,
      color: section.color,
      subtitle: subtitle,
      badge: badge,
      badgeColor: badgeColor
    )
    .tag(section)
  }
}
