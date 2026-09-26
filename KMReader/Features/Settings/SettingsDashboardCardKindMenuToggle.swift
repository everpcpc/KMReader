//
// SettingsDashboardCardKindMenuToggle.swift
//
//

import SwiftUI

/// The switch for the card kind menu shown at the trailing edge of each
/// dashboard section header.
struct SettingsDashboardCardKindMenuToggle: View {
  @AppStorage("showDashboardCardKindMenu") private var showDashboardCardKindMenu: Bool = true

  var body: some View {
    Toggle(isOn: $showDashboardCardKindMenu) {
      VStack(alignment: .leading, spacing: 4) {
        Text(String(localized: "settings.dashboard.cardKindMenu.title"))
        Text(String(localized: "settings.dashboard.cardKindMenu.caption"))
          .font(.caption)
          .foregroundColor(.secondary)
      }
    }
  }
}
